"""
---------------------------------------------------------------------------------------------------------------------
Name: NHA_Form_Transfer.py
Purpose: This script transfers NHA update form responses to the NHA geodatabase for storage and use. This script will
be set up to run nightly through task scheduler.
Author: Molly Moore for Pennsylvania Natural Heritage Program
Created: 11/1/2024
Updates:
------------------------------------------------------------------------------------------------------------------------
"""

# import packages
import arcpy
from arcgis.gis import GIS
from arcgis.features import FeatureLayer
from arcgis.features import GeoAccessor
import os
import sys
import pandas as pd
import numpy as np
import re

# environment variables
pd.options.mode.copy_on_write = True
arcpy.env.overwriteOutput = True

# define NHA geodatabase rest endpoints
nha = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/0"
nha_site_account = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/5"
tr_bullets = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/7"
nha_references = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/4"

# define rest endpoint for zotero references
zotero_ref_url = r"https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/5"

# define ID number for the NHA form survey - this can be found @ Portal information page for survey (in address bar)
survey_id = '3360207b68a94e03b125b14804fcf906'

# load gis credentials from OS environment variables - these need to be setup in your operating system environment variables
wpc_gis_username = os.environ.get("wpc_portal_username")
wpc_gis_password = os.environ.get("wpc_gis_password")
# connect to Portal account
gis = GIS('https://gis.waterlandlife.org/portal', wpc_gis_username, wpc_gis_password)

# get NHA form layer collection using survey ID number found @ Portal information page
nha_form_collection = gis.content.get(survey_id)

# define layer and tables here - WILL NEED TO CHANGE IF UPDATES ARE MADE THAT IMPACT THE INDEXES OF LAYERS/TABLES
nha_form_lyr = nha_form_collection.layers[0]
site_desc_ref_tbl = nha_form_collection.tables[0]
threats_ref_tbl = nha_form_collection.tables[1]
tr_repeat_tbl = nha_form_collection.tables[2]

# get all nha surveys in feature layer and convert to Pandas dataframe
nha_surveys = nha_form_lyr.query()
nha_surveys_df = nha_surveys.sdf

# get site description references and convert to Pandas dataframe
site_ref = site_desc_ref_tbl.query()
site_ref_df = site_ref.sdf

# get threats/recs summary references and convert to Pandas dataframe
threats_ref = threats_ref_tbl.query()
threats_ref_df = threats_ref.sdf

# get threat/rec bullets and convert to Pandas dataframe
tr_repeat = tr_repeat_tbl.query()
tr_repeat_df = tr_repeat.sdf

########################################################################################################################
## First, we are going to load in site account records if needed -- these will only be those that have updates to site
## description or threats and recommendations summary records
########################################################################################################################

# now get a dataframe of only the most recent site accounts per NHA in the nha geodatabase so that we can transfer
# the site description or threats/recs summary if one is approved and one is updated.
def get_latest_records(feature_layer_url, id_field, date_field):
    """
    Fetches data from a feature layer, keeps only the most recent record for each ID,
    and returns a Pandas DataFrame.
    """

    # Create a FeatureLayer object
    fl = FeatureLayer(feature_layer_url)

    # Query all features from the layer and convert to pandas dataframe
    df = fl.query(out_fields='*', return_geometry=False).sdf

    if not df.empty:
        # Sort by ID and date field in descending order
        df.sort_values([id_field, date_field], ascending=[True, False], inplace=True)

        # Drop duplicates, keeping only the first (most recent) record for each ID
        df.drop_duplicates(subset=[id_field], keep='first', inplace=True)

    return df


# get df of most recent site accounts
current_site_accounts = get_latest_records(nha_site_account, "nha_join_id", "created_date")

# get dataframe of proposed new NHAs that have site account records filled out in the form OR site accounts that have
# updates to the site description and/or threats/recs summary. these records will be loaded into the Site Account NHA
# geodatabase table
load_sites_df = nha_surveys_df[(((nha_surveys_df['objective'] == "new") & (nha_surveys_df['update_nha'] == "y")) | (
        (nha_surveys_df['objective'] == "update") & (
            (nha_surveys_df['site_desc_approve'] == "update") | (nha_surveys_df['threat_approve'] == "update")))) & nha_surveys_df['load_status'].isna()]

# The following section formats the dataframe and fills attributes where necessary to get it ready to load into the
# NHA geodatabase
# fill site name with proposed site name for new/updated surveys
load_sites_df['site_name'] = load_sites_df['site_name'].fillna(
    load_sites_df['proposed_name'].where(load_sites_df['objective'] == 'new'))

# copy most recent site description from nha geodatabase if site description is approved in form
join_mapping = current_site_accounts.set_index('nha_join_id')['site_desc'].to_dict()
load_sites_df['site_desc'] = load_sites_df['site_desc'].fillna(load_sites_df['nha_join_id'].map(join_mapping))

# copy most recent tr_summary from nha geodatabase if tr_summary is approved in form
join_mapping = current_site_accounts.set_index('nha_join_id')['tr_summary'].to_dict()
load_sites_df['tr_summary'] = load_sites_df['tr_summary'].fillna(load_sites_df['nha_join_id'].map(join_mapping))

# create review_date field and fill it with the written_date
load_sites_df['review_date'] = load_sites_df['written_date']
# format the pandas NA types so that they play nicely with ArcGIS and come in as Null values appropriately
load_sites_df = load_sites_df.fillna(np.nan)
load_sites_df = load_sites_df.replace({np.nan: None})

# define list of fields to be loaded into NHA geodatabase from form and convert them into a tuple - this is what will be
# compared to existing records and if they do not exist in the nha geodatabase yet, they will be loaded.
insert_fields = ["site_name", "site_desc", "tr_summary", "written_user", "written_date", "written_notes", "review_user",
                 "review_date", "review_notes", "nha_join_id", "nha_rel_guid"]
insert_tuples = list(load_sites_df[insert_fields].itertuples(index=False, name=None))

# get list of existing site accounts in the nha geodatabase, so we don't load in duplicate records below
all_site_accounts = []
with arcpy.da.SearchCursor(nha_site_account,
                           ["site_name", "site_desc", "tr_summary", "written_user", "written_date", "written_notes",
                            "review_user", "review_date", "review_notes", "nha_join_id", "nha_rel_GUID"]) as cursor:
    for row in cursor:
        all_site_accounts.append(row)

# for each site account record to be loaded into the NHA geodatabase site accounts, check if it already exists in
# geodatabase - if it does, skip it. if it doesn't, load it in.
insert_fields.append("status")
for record in insert_tuples:
    nha_join_id = record[9]
    if record in all_site_accounts:
        print("An duplicate record with the site name " + record[0] + " is already in the NHA Site Account table.")
        print(nha_form_lyr.calculate(where="nha_join_id = '{}'".format(nha_join_id), calc_expression={"field": "load_status", "value": "loaded"}))
        pass
    else:
        print(record)
        record += ("rev",)
        with arcpy.da.InsertCursor(nha_site_account, insert_fields) as cursor:
            cursor.insertRow(record)
        # change load status to "loaded" for the record, so we don't keep loading it in if something changes in the .gdb.
        print(nha_form_lyr.calculate(where="nha_join_id = '{}'".format(nha_join_id), calc_expression={"field": "load_status", "value": "loaded"}))

########################################################################################################################
## Now we are going to edit the review fields of existing site account records if both the site description and threats/
## recs summary are approved in the nha form.
########################################################################################################################

# create dataframe with site account records that are marked as approved
approve_sites_df = nha_surveys_df[
    (nha_surveys_df['objective'] == "update") & (nha_surveys_df['site_desc_approve'] == "approve") & (
            nha_surveys_df['threat_approve'] == "approve") & nha_surveys_df['site_review_status'].isna()]
# format the pandas NA types so that they play nicely with ArcGIS and come in as Null values appropriately
approve_sites_df = approve_sites_df.fillna(np.nan)
approve_sites_df = approve_sites_df.replace({np.nan: None})

# create dictionary of values to update
approve_dict = approve_sites_df.set_index('nha_join_id')[["review_user", "written_date", "review_notes"]].apply(list,
                                                                                                                axis=1).to_dict()

# create list of nha_join_ids to loop through because I think this will be faster than going through ALL the cursors
approve_ids = approve_sites_df['nha_join_id'].tolist()
# create where clause for the update cursor based on how many records we are updating - if updating more than 1, we need
# to use a tuple IN clause, but if only one record, we need to use equal condition. If there are no records, pass because
# we will check for that before starting the loop.
if len(approve_ids) > 1:
    where_clause = "nha_join_id IN {0}".format(tuple(approve_ids))
elif len(approve_ids) == 1:
    where_clause = "nha_join_id = '{0}'".format(approve_ids[0])
else:
    pass

# first, check to see if there are any approved records, then update review fields in the site account table for the
# approved records
if approve_ids:
    with arcpy.da.UpdateCursor(nha_site_account,
                               ["nha_join_id", "review_user", "review_date", "review_notes", "status", "written_date"],
                               where_clause) as cursor:
        for row in cursor:
            print("Updating review fields for nha_join_id " + row[0])
            for k, v in approve_dict.items():
                if row[0] == k:
                    row[1] = v[0]
                    row[2] = v[1]
                    row[3] = v[2]
                    row[4] = "app"
                    cursor.updateRow(row)
                    print(nha_form_lyr.calculate(where="nha_join_id = '{}'".format(k),
                                                  calc_expression={"field": "site_review_status", "value": "loaded"}))

########################################################################################################################
## Now we are going to edit the review fields for the NHA layer if mapping/species are approved
########################################################################################################################

# create dataframe where mapping and species are both approved
approve_map_df = nha_surveys_df[
    (nha_surveys_df['mapping_update'] == "no") & (nha_surveys_df['species_update'] == "no") & (nha_surveys_df['map_review_status'].isna())]

# format the pandas NA types so that they play nicely with ArcGIS and come in as Null values appropriately
approve_map_df = approve_map_df.fillna(np.nan)
approve_map_df = approve_map_df.replace({np.nan: None})

# create dictionary of values to update
approve_dict = approve_map_df.set_index('nha_join_id')[["created_user", "written_date"]].apply(list, axis=1).to_dict()

# create list of nha_join_ids to loop through because I think this will be faster than going through ALL the cursors
approve_ids = approve_map_df['nha_join_id'].tolist()
# create where clause for the update cursor based on how many records we are updating - if updating more than 1, we need
# to use a tuple IN clause, but if only one record, we need to use equal condition. If there are no records, pass because
# we will check for that before starting the loop.
if len(approve_ids) > 1:
    where_clause = "nha_join_id IN {0}".format(tuple(approve_ids))
elif len(approve_ids) == 1:
    where_clause = "nha_join_id = '{0}'".format(approve_ids[0])
else:
    pass

# first, check to see if there are any approved records, then update review fields in the site account table for the
# approved records
if approve_ids:
    with arcpy.da.UpdateCursor(nha,
                               ["nha_join_id", "status", "status_change_date", "status_change_reason", "review_user",
                                "review_date"], where_clause) as cursor:
        for row in cursor:
            print("Updating review fields for nha_join_id " + row[0])
            for k, v in approve_dict.items():
                if row[0] == k:
                    row[1] = "app"
                    row[2] = v[1]
                    row[3] = "Mapping and species list approval were submitted in NHA update form."
                    row[4] = v[0]
                    row[5] = v[1]
                    cursor.updateRow(row)
                    print(nha_form_lyr.calculate(where="nha_join_id = '{}'".format(k),
                                                  calc_expression={"field": "map_review_status", "value": "loaded"}))


########################################################################################################################
## Now we are going to edit the review fields for the NHA layer if mapping/species are NOT approved
########################################################################################################################


# create dataframe where mapping OR species are NOT approved
unapprove_map_df = nha_surveys_df[
    ((nha_surveys_df['mapping_update'] == "yes") | (nha_surveys_df['species_update'] == "yes")) & (nha_surveys_df['map_review_status'].isna())]

# format the pandas NA types so that they play nicely with ArcGIS and come in as Null values appropriately
unapprove_map_df = unapprove_map_df.fillna(np.nan)
unapprove_map_df = unapprove_map_df.replace({np.nan: None})

unapprove_map_df['review_notes'] = unapprove_map_df['mapping_update_notes'].fillna('').str.cat(unapprove_map_df['species_update_notes'].fillna(''), sep=' ')

# create dictionary of values to update
unapprove_dict = unapprove_map_df.set_index('nha_join_id')[["created_user", "written_date", "review_notes"]].apply(list, axis=1).to_dict()

# create list of nha_join_ids to loop through because I think this will be faster than going through ALL the cursors
unapprove_ids = unapprove_map_df['nha_join_id'].tolist()
# create where clause for the update cursor based on how many records we are updating - if updating more than 1, we need
# to use a tuple IN clause, but if only one record, we need to use equal condition. If there are no records, pass because
# we will check for that before starting the loop.
if len(unapprove_ids) > 1:
    where_clause = "nha_join_id IN {0}".format(tuple(unapprove_ids))
elif len(unapprove_ids) == 1:
    where_clause = "nha_join_id = '{0}'".format(unapprove_ids[0])
else:
    pass

# first, check to see if there are any approved records, then update review fields in the site account table for the
# approved records
if unapprove_ids:
    with arcpy.da.UpdateCursor(nha,
                               ["nha_join_id", "status", "status_change_date", "status_change_reason", "review_user",
                                "review_date", "review_notes"], where_clause) as cursor:
        for row in cursor:
            print("Updating review fields for nha_join_id " + row[0])
            for k, v in unapprove_dict.items():
                if row[0] == k:
                    row[1] = "rev"
                    row[2] = v[1]
                    row[3] = "NHA needs to be reviewed. Mapping and/or species list need to be updated per the NHA update form."
                    row[4] = v[0]
                    row[5] = v[1]
                    row[6] = v[2]
                    cursor.updateRow(row)
                    print(nha_form_lyr.calculate(where="nha_join_id = '{}'".format(k),
                                                  calc_expression={"field": "map_review_status", "value": "loaded"}))


########################################################################################################################
## Now we are going to add the threats and recommendations bullet points if any were added
########################################################################################################################
# get dataframe of tr_repeats from survey123 form, but only include those that have a null load status because those are
# the records we have not loaded yet.
tr_repeat_df = tr_repeat_df[tr_repeat_df['load_status'].isna()]
tr_repeat_df = pd.merge(tr_repeat_df, nha_surveys_df[['nha_join_id','written_date','site_name','uniquerowid','nha_rel_guid']], left_on='parentrowid', right_on='uniquerowid', how='left')

# format the pandas NA types so that they play nicely with ArcGIS and come in as Null values appropriately
tr_repeat_df = tr_repeat_df.fillna(np.nan)
tr_repeat_df = tr_repeat_df.replace({np.nan: None})

# define list of fields to be loaded into NHA geodatabase tr_bullets table from form and convert them into a tuple -
# this is what will be compared to existing records and if they do not exist in the nha geodatabase yet, they will be loaded.
insert_fields = ["site_name", "threat_category", "threat", "threat_text", "created_user", "written_date", "nha_join_id", "nha_rel_guid", "globalid"]
insert_tuples = list(tr_repeat_df[insert_fields].itertuples(index=False, name=None))

# get list of existing tr_bullets in the nha geodatabase, so we don't load in duplicate records below
all_tr_bullets = []
with arcpy.da.SearchCursor(tr_bullets,
                           ["site_name", "target_category", "threat_desc", "threat_text", "added_user", "added_date",
                            "nha_join_id", "nha_rel_GUID"]) as cursor:
    for row in cursor:
        all_tr_bullets.append(row)

# for each tr_bullet record to be loaded into the NHA geodatabase, check if it already exists in geodatabase - if it
# does, skip it. if it doesn't, load it in.
for record in insert_tuples:
    # get unique id for the form row, so that we can use it to change the load status after we load the record.
    unique_id = record[8]
    record = record[:-1]
    if record in all_tr_bullets:
        print("A duplicate record with the site name " + record[0] + " is already in the NHA TR bullets table.")
        # update load_status field to loaded, so that we don't try to load these again.
        print(tr_repeat_tbl.calculate(where="globalid = '{}'".format(unique_id), calc_expression={"field": "load_status", "value": "loaded"}))
        pass
    else:
        print(record)
        record += ("Added with the NHA Update Form.",)
        with arcpy.da.InsertCursor(tr_bullets, ["site_name", "target_category", "threat_desc", "threat_text",
                                                      "added_user", "added_date", "nha_join_id", "nha_rel_GUID", "added_notes"]) as cursor:
            cursor.insertRow(record)
        # update load_status field to loaded, so that we don't try to load these again.
        print(tr_repeat_tbl.calculate(where="globalid = '{}'".format(unique_id), calc_expression={"field": "load_status", "value": "loaded"}))


########################################################################################################################
## Now we are going to add references to the references and citations table
########################################################################################################################
# change column names of reference dfs to match
site_ref_df = site_ref_df.rename(columns={'key_1': 'key'})
threats_ref_df = threats_ref_df.rename(columns={'key_2': 'key'})
# add field to identify source field
site_ref_df['source_field'] = 'site_desc'
threats_ref_df['source_field'] = 'tr_summary'

# concatenate the two reference dataframes
references_df = pd.concat([site_ref_df[['key','parentrowid','source_field']], threats_ref_df[['key','parentrowid','source_field']]], axis=0)

# merge in the parent global ID for site account GUID
references_df = pd.merge(references_df, nha_surveys_df[['uniquerowid','nha_rel_guid','nha_join_id']], how= 'left', left_on="parentrowid", right_on="uniquerowid")

# load zotero references table from the NHA reference feature service
zotero_flayer = FeatureLayer(zotero_ref_url)
zotero_fset = zotero_flayer.query()
zotero_df = zotero_fset.sdf

# merge in zotero columns from zotero primary list
references_df = pd.merge(references_df, zotero_df[['key', 'title', 'authors', 'publication_year']], how='left', on='key')
# format the pandas NA types so that they play nicely with ArcGIS and come in as Null values appropriately
references_df = references_df.fillna(np.nan)
references_df = references_df.replace({np.nan: None})

# create list of tuples to be loaded into geodatabase
insert_fields = ["key", "nha_join_id", "title", "authors", "publication_year", "source_field"]
insert_tuples = list(references_df[insert_fields].itertuples(index=False, name=None))

# get list of existing references nha geodatabase, so we don't load in duplicate records below
all_refs = []
with arcpy.da.SearchCursor(nha_references,
                           ["zotero_key", "source_id", "title", "authors", "publication_yr", "source_field"]) as cursor:
    for row in cursor:
        all_refs.append(row)

# for each reference record to be loaded into the NHA geodatabase, check if it already exists in geodatabase - if it
# does, skip it. if it doesn't, load it in.
for record in insert_tuples:
    if record in all_refs:
        pass
    else:
        print(record)
        record += ("site_account",)
        with arcpy.da.InsertCursor(nha_references, ["zotero_key", "source_id", "title", "authors", "publication_yr",
                                                "source_field", "source_table"]) as cursor:
            cursor.insertRow(record)

# NOW WE NEED TO FILL site_rel_GUID field with most recent site that matches nha_join_id
# get updated dataframe of most recent site account records per nha_join_id after we added our sites
current_site_accounts = get_latest_records(nha_site_account, "nha_join_id", "created_date")

# create dictionary of values to update and remove rows with a null nha_join_id
current_site_dict = current_site_accounts.set_index('nha_join_id')[["GlobalID"]].apply(list, axis=1).to_dict()
current_site_dict ={k: v for k, v in current_site_dict.items() if pd.Series(k).notna().all()}


# create update cursor for any site account record that has a null site_account_GUID and fill with most recent site account
# record that matches the nha_join_id - this should be a relatively accurate way to link up the references with the correct
# site account record as long as this is run regularly and kept up to date.
with arcpy.da.UpdateCursor(nha_references,["source_id","site_account_GUID"], "source_table = 'site_account' AND site_account_GUID IS NULL") as cursor:
    for row in cursor:
        if row[0] is None:
            pass
        else:
            for k,v in current_site_dict.items():
                if k == row[0]:
                    row[1] = v[0]
                    cursor.updateRow(row)

########################################################################################################################
# Add photos
# in this section, we will take all nha form records that indicate a "new" photo. We will get the object ids from those
# records in the nha survey form and in the matching records in the nha geodatabase layer and join them based on
# nha_join_id
########################################################################################################################

# define temporary path where photos will be temporarily be saved and create folders if they don't yet exist. This path
# can be cleaned out periodically if needed
temp_photo_path = r"C:\temp\survey123photos"
if not os.path.exists(temp_photo_path):
    os.makedirs(temp_photo_path)

# query nha survey form feature layer to get records that have new photos and turn into dataframe
new_photo_query = nha_form_lyr.query(where="photo_approve = 'new' and nha_join_id IS NOT NULL", out_fields='objectid,nha_join_id,photo_credit,photo_affil,photo_caption')
new_photo_df = new_photo_query.sdf
# rename the OID field, so we can distinguish it from the geodatabase OID field later
new_photo_df = new_photo_df.rename(columns={'objectid': 'new_photo_oid'})
# get tuple of nha_join_ids for records with photos that need to be added, so we can query the nha layer and speed things up
nha_join_ids = tuple(new_photo_df["nha_join_id"])

# create feature layer object from NHA geodatabase rest endpoint
nha_lyr = FeatureLayer(nha)
# depending on number of records that have photos that need to be added, construct query. If the length of the tuple is
# 0, then we will define the variable as false, and we will not go through the steps to try to load.
if len(nha_join_ids) == 1:
    where_clause = "nha_join_id = '{}'".format(nha_join_ids[0])
elif len(nha_join_ids) > 1:
    where_clause = "nha_join_id IN {}".format(nha_join_ids)
else:
    where_clause = False

# check if where_clause is False due to having 0 records to load. Move on if there are records. Stop and print message
# if there are not.
if where_clause:
    # query NHA feature layer object using where clause defined above. we only need objectid and nha_join_id fields in output
    nha_query = nha_lyr.query(where= where_clause, out_fields='objectid,nha_join_id')
    # turn output of query into dataframe
    nha_df = nha_query.sdf

    # join the object ids from the geodatabase layer to the dataframe of survey123 form records based on matching
    # nha_join_ids. basically, we want to get the objectids from the survey123 form that correspond to the object ids in
    # the matching NHA in the geodatabase layer
    new_photo_df = pd.merge(new_photo_df, nha_df[["nha_join_id", "OBJECTID"]], on="nha_join_id")
    # format the pandas NA types so that they play nicely with ArcGIS and come in as Null values appropriately
    new_photo_df = new_photo_df.fillna(np.nan)
    new_photo_df = new_photo_df.replace({np.nan: None})

    # create list of tuples that we will use to load records and update attributes
    new_photo_fields = ["nha_join_id", "new_photo_oid", "OBJECTID", "photo_credit", "photo_affil", "photo_caption"]
    new_photo_tuples = list(new_photo_df[new_photo_fields].itertuples(index=False, name=None))

    # start loop to load each new photo record and update attributes
    for photo_record in new_photo_tuples:
        # define oids and other attributes for easier handling below
        photo_oid = str(photo_record[1])
        geodatabase_oid = str(photo_record[2])
        photo_credit = photo_record[3]
        photo_affil = photo_record[4]
        photo_caption = photo_record[5]
        # get attachment dictionary from nha_form_lyr - we can define this as first element because we are only collecting
        # a single photo in each form. We are defining the dictionary here so that we can use the attachment id in the next
        # line.
        attachment = nha_form_lyr.attachments.get_list(photo_oid)
        if attachment:
            attachment = nha_form_lyr.attachments.get_list(photo_oid)[0]
            # download the photo from the nha_form_lyr to the temporary output folder space
            downloaded_photo = nha_form_lyr.attachments.download(oid=photo_oid, attachment_id=attachment['id'], save_path=temp_photo_path)[0]
            # print statement
            print("Successfully downloaded photo: " + downloaded_photo)

            # get list of attachments from nha geodatabase layer to check if we need to delete attachment first because we
            # only want to maintain one attached photo for each nha
            nha_lyr_attachment = nha_lyr.attachments.get_list(geodatabase_oid)
            # if the nha geodatabase layer has attachments already, delete them
            if len(nha_lyr_attachment):
                print("The NHA with OID: " + str(geodatabase_oid) + " has " + str(len(nha_lyr_attachment)) + " existing attachments that will be deleted.")
                for attachment in nha_lyr_attachment:
                    nha_lyr.attachments.delete(oid=geodatabase_oid, attachment_id=attachment['id'])

            # add attachment to geodatabase layer
            nha_lyr.attachments.add(geodatabase_oid, downloaded_photo)

            # update photo credit, photo affil, and photo caption fields in the nha geodatabase layer
            with arcpy.da.UpdateCursor(nha,["photo_credit","photo_affil","photo_caption"],where_clause="OBJECTID = {}".format(geodatabase_oid)) as cursor:
                for row in cursor:
                    row[0] = photo_credit
                    row[1] = photo_affil
                    row[2] = photo_caption
                    cursor.updateRow(row)

            # update photo_approve attribute of records in nha survey123 form to existing, so that we don't try to load the
            # photos in again in the future
            print(nha_form_lyr.calculate(where="objectid = '{}'".format(photo_oid), calc_expression={"field": "photo_approve", "value": "existing"}))
else:
    # report print statement if there are no new photos that need to be added
    print("There are no records with new photos that need to be added.")
    pass


########################################################################################################################
# fill related globalIDs - we shouldn't have to do this much, but we use this in case something goes wrong with a name
# or nha_join_id query in the form.
########################################################################################################################

# def update_rel_guid(parent_feature, primary_key, child_feature, foreign_key, related_guid):
#     related_dict = {row[0]: row[1] for row in arcpy.da.SearchCursor(parent_feature, [primary_key, "GlobalID"]) if
#                     row[0] is not None}
#     with arcpy.da.UpdateCursor(child_feature, [foreign_key, related_guid]) as cursor:
#         for row in cursor:
#             for k, v in related_dict.items():
#                 if k == row[0]:
#                     row[1] = v
#                     cursor.updateRow(row)
#                 else:
#                     pass
#
#
# # update relative GlobalIDs in child tables
# update_rel_guid(nha, "nha_join_id", tr_bullets, "nha_join_id", "nha_rel_GUID")

