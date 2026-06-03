"""
---------------------------------------------------------------------------------------------------------------------
Name: NHA_Public_Update.py
Purpose: This script deletes all features from the NHA public dataset and copies and formats NHA data from our
internal NHA database to the public feature service.
Author: Molly Moore for Pennsylvania Natural Heritage Program
Created: 03/24/2025
Updates:
------------------------------------------------------------------------------------------------------------------------
"""

# choose whether to include attachments - this will take an extra 20-30 minutes, but will include attachment transfer
attachments = "yes"
#attachments = "no"

# import packages
import arcpy
from arcgis.gis import GIS
from arcgis.features import FeatureLayer
from arcgis.features import FeatureSet
import os
import pandas as pd
import numpy as np
import shutil
import re

# environment variables
pd.options.mode.copy_on_write = True
arcpy.env.overwriteOutput = True

# define function to take feature layer and keep only most recent record. Returns a Pandas DF. We will use this function
# below to get most recent site account entries.
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

        # Drop rows that have null id field
        df.dropna(subset=[id_field])

    return df


# define NHA feature service rest endpoints
nha_url = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/0"
site_account_url = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/5"
species_url = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/6"
tr_bullets_url = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/7"
nha_references_url = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/4"

# eo rest end point to bring in current EO data
eo_ptreps = r"https://gis.waterlandlife.org/server/rest/services/PNHP/Biotics_READ_ONLY/FeatureServer/0"

# define NHA PUBLIC feature service rest endpoints - these are on our WEBGIS Portal
PUBLIC_nha_url = r"https://services2.arcgis.com/XM2fovFQqAVipH6f/arcgis/rest/services/Natural_Heritage_Area_Public_Data/FeatureServer/0"
PUBLIC_susns_url = r"https://services2.arcgis.com/XM2fovFQqAVipH6f/arcgis/rest/services/Natural_Heritage_Area_Public_Data/FeatureServer/1"
PUBLIC_site_accounts_url = r"https://services2.arcgis.com/XM2fovFQqAVipH6f/arcgis/rest/services/Natural_Heritage_Area_Public_Data/FeatureServer/3"
PUBLIC_species_url = r"https://services2.arcgis.com/XM2fovFQqAVipH6f/arcgis/rest/services/Natural_Heritage_Area_Public_Data/FeatureServer/2"
PUBLIC_tr_bullets_url = r"https://services2.arcgis.com/XM2fovFQqAVipH6f/arcgis/rest/services/Natural_Heritage_Area_Public_Data/FeatureServer/4"
PUBLIC_nha_references_url = r"https://services2.arcgis.com/XM2fovFQqAVipH6f/arcgis/rest/services/Natural_Heritage_Area_Public_Data/FeatureServer/5"

###################
## FIRST WE ARE GOING TO CONNECT TO THE WPC GIS PORTAL AND BRING IN ALL THE DATA AT ONCE SO WE DON'T  HAVE TO KEEP SWITCHING PORTALS
# load wpc gis portal credentials from OS environment variables - these need to be setup in your operating system environment variables
wpc_gis_username = os.environ.get("wpc_portal_username")
wpc_gis_password = os.environ.get("wpc_gis_password")
# connect to wpc gis Portal account
gis = GIS('https://gis.waterlandlife.org/portal', wpc_gis_username, wpc_gis_password)

# make a layer of nha cores that are ready for review or approved - EXCLUDE draft and not approved. These will be loaded
# into the public layer in a bit

field_mapping = 'site_name "Site Name" true true false 255 Text 0 0,First,#,Natural Heritage Areas,site_name,0,254;site_type "Site Type" true true false 4 Text 0 0,First,#,Natural Heritage Areas,site_type,0,3;desc_ "Brief Description" true true false 1000 Text 0 0,First,#,Natural Heritage Areas,desc_,0,999;status "Drawn Status" true true false 3 Text 0 0,First,#,Natural Heritage Areas,status,0,2;status_change_date "Status Change Date" true true false 8 Date 0 0,First,#,Natural Heritage Areas,status_change_date,-1,-1;status_change_reason "Status Change Reason" true true false 1000 Text 0 0,First,#,Natural Heritage Areas,status_change_reason,0,999;drawn_user "Drawn User" true true false 100 Text 0 0,First,#,Natural Heritage Areas,drawn_user,0,99;drawn_date "Drawn Date" true true false 8 Date 0 0,First,#,Natural Heritage Areas,drawn_date,-1,-1;drawn_notes "Drawn Notes" true true false 1000 Text 0 0,First,#,Natural Heritage Areas,drawn_notes,0,999;review_user "Review User" true true false 100 Text 0 0,First,#,Natural Heritage Areas,review_user,0,99;review_date "Review Date" true true false 8 Date 0 0,First,#,Natural Heritage Areas,review_date,-1,-1;review_notes "Review Notes" true true false 1000 Text 0 0,First,#,Natural Heritage Areas,review_notes,0,999;sig_rank "Significance Rank" true true false 12 Text 0 0,First,#,Natural Heritage Areas,sig_rank,0,1;sig_rank_comm "Significance Rank Comments" true true false 1000 Text 0 0,First,#,Natural Heritage Areas,sig_rank_comm,0,999;project "Project" true true false 255 Text 0 0,First,#,Natural Heritage Areas,project,0,254;source_report "Source Report" true true false 255 Text 0 0,First,#,Natural Heritage Areas,source_report,0,254;site_pdf_link "Site Account PDF Link" true true false 255 Text 0 0,First,#,Natural Heritage Areas,site_pdf_link,0,254;wpc_blueprint "WPC Blueprint?" true true false 2 Text 0 0,First,#,Natural Heritage Areas,wpc_blueprint,0,1;nha_join_id "NHA Join ID" true true false 25 Text 0 0,First,#,Natural Heritage Areas,nha_join_id,0,24;GlobalID "GlobalID" false false true 38 GlobalID 0 0,First,#,Natural Heritage Areas,GlobalID,-1,-1;created_user "created_user" false true true 255 Text 0 0,First,#,Natural Heritage Areas,created_user,0,254;created_date "created_date" false true true 8 Date 0 0,First,#,Natural Heritage Areas,created_date,-1,-1;last_edited_user "last_edited_user" false true true 255 Text 0 0,First,#,Natural Heritage Areas,last_edited_user,0,254;last_edited_date "last_edited_date" false true true 8 Date 0 0,First,#,Natural Heritage Areas,last_edited_date,-1,-1;photo_credit "Photo Credit Name" true true false 255 Text 0 0,First,#,Natural Heritage Areas,photo_credit,0,254;photo_affil "Photo Credit Affiliation" true true false 255 Text 0 0,First,#,Natural Heritage Areas,photo_affil,0,254;photo_caption "Photo Caption" true true false 255 Text 0 0,First,#,Natural Heritage Areas,photo_caption,0,254;Shape__Area "Shape.STArea()" false true true 0 Double 0 0,First,#,Natural Heritage Areas,Shape__Area,-1,-1;Shape__Length "Shape.STLength()" false true true 0 Double 0 0,First,#,Natural Heritage Areas,Shape__Length,-1,-1'

nha_copy = arcpy.FeatureClassToFeatureClass_conversion(nha_url, "memory", "nha_copy", where_clause = "site_type <> 'susn' AND (status = 'rev' OR status = 'app')", field_mapping=field_mapping)
with arcpy.da.UpdateCursor(nha_copy,["site_type","sig_rank"]) as cursor:
    for row in cursor:
        if row[0] == "hist":
            row[1] = "H"
            cursor.updateRow(row)

with arcpy.da.UpdateCursor(nha_copy,"sig_rank") as cursor:
    for row in cursor:
        if row[0] is None:
            pass
        elif row[0] == "G":
            row[0] = "Global"
            cursor.updateRow(row)
        elif row[0] == "R":
            row[0] = "Regional"
            cursor.updateRow(row)
        elif row[0] == "S":
            row[0] = "State"
            cursor.updateRow(row)
        elif row[0] == "L":
            row[0] = "Local"
            cursor.updateRow(row)
        else:
            row[0] = "Historic"
            cursor.updateRow(row)

with arcpy.da.UpdateCursor(nha_copy, ["photo_caption", "photo_credit", "photo_affil"]) as cursor:
    for row in cursor:
        if row[0] is not None:
            if row[1] is not None and row[2] is not None:
                photo_cap = row[0]+" Photo by: "+row[1]+", "+row[2]
            elif row[1] is None and row[2] is not None:
                photo_cap = row[0]+" Photo by: "+row[2]
            elif row[1] is not None and row[2] is None:
                photo_cap = row[0]+" Photo by: "+row[1]
            else:
                photo_cap = row[0]
            row[0] = photo_cap
            cursor.updateRow(row)
nha_layer = arcpy.MakeFeatureLayer_management(nha_copy, "nha_layer", where_clause = "site_type <> 'susn' AND (status = 'rev' OR status = 'app')")


#########################
## PREP SUSNs
#########################
susn_copy = arcpy.FeatureClassToFeatureClass_conversion(nha_url, "memory", "susn_copy", where_clause = "site_type = 'susn' AND (status = 'rev' OR status = 'app')", field_mapping=field_mapping)

with arcpy.da.UpdateCursor(susn_copy,"sig_rank") as cursor:
    for row in cursor:
        if row[0] is None:
            pass
        elif row[0] == "G":
            row[0] = "Global"
            cursor.updateRow(row)
        elif row[0] == "R":
            row[0] = "Regional"
            cursor.updateRow(row)
        elif row[0] == "S":
            row[0] = "State"
            cursor.updateRow(row)
        elif row[0] == "L":
            row[0] = "Local"
            cursor.updateRow(row)
        else:
            row[0] = "Historic"
            cursor.updateRow(row)

with arcpy.da.UpdateCursor(susn_copy, ["photo_caption", "photo_credit", "photo_affil"]) as cursor:
    for row in cursor:
        if row[0] is not None:
            if row[1] is not None and row[2] is not None:
                photo_cap = row[0]+" Photo by: "+row[1]+", "+row[2]
            elif row[1] is None and row[2] is not None:
                photo_cap = row[0]+" Photo by: "+row[2]
            elif row[1] is not None and row[2] is None:
                photo_cap = row[0]+" Photo by: "+row[1]
            else:
                photo_cap = row[0]
            row[0] = photo_cap
            cursor.updateRow(row)
susn_layer = arcpy.MakeFeatureLayer_management(susn_copy, "susn_layer", where_clause = "site_type = 'susn' AND (status = 'rev' OR status = 'app')")

##########################
## LOAD SITE ACCOUNTS
##########################
# load in the most current site account records for all NHAs
site_accounts = get_latest_records(site_account_url,"nha_join_id","written_date")
site_accounts = site_accounts.where(pd.notnull(site_accounts), None)

# Fix date columns (NaT survives .where() and must be handled separately)
date_cols = site_accounts.select_dtypes(include=['datetime64[ns]', 'datetimetz']).columns
for col in date_cols:
    site_accounts[col] = site_accounts[col].apply(
        lambda x: None if pd.isnull(x) else int(x.timestamp() * 1000)
    )

site_accounts_df = site_accounts[['site_desc','tr_summary','nha_join_id','written_date']]

italics_path = r"H:\Scripts\NHA_Tools\SiteReports\_data\SNAMEitalics.csv"
ETitalics = pd.read_csv(italics_path)["ETitalics"].tolist()
# Remove problematic names
ETitalics = [s for s in ETitalics if s != "Alle"]

# Build a single regex pattern: (Species1|Species2|Species3...)
pattern = re.compile(r'(' + '|'.join(map(re.escape, ETitalics)) + r')')
# Replacement function: wrap match in <i>...</i>
def replacer(match):
    return f"<i>{match.group(0)}</i>"
# Function to process one string
def italicize_text(text):
    if pd.isna(text):
        return text
    return pattern.sub(replacer, text)


# Apply to entire dataframe column at once (much faster)
site_accounts_df["site_desc"] = site_accounts_df["site_desc"].map(italicize_text)
site_accounts_df["tr_summary"] = site_accounts_df["tr_summary"].map(italicize_text)

# ETbold = sorted({row[0] for row in arcpy.da.SearchCursor(eo_ptreps,"SCOMNAME")})
#
# # Remove empty strings just in case
# ETbold = [t for t in ETbold if t.strip() != ""]
#
# # Sort longest first to avoid partial matches
# ETbold.sort(key=len, reverse=True)
#
# bold_pattern = re.compile(r'(' + '|'.join(map(re.escape, ETbold)) + r')', re.IGNORECASE)
#
# # Replacement function: wrap matched text in <b>...</b>
# def bold_replacer(match):
#     return f"<b>{match.group(0)}</b>"
#
# def bold_text(text):
#     if pd.isna(text):
#         return text
#     return bold_pattern.sub(bold_replacer, text)


# Apply to your dataframe columns
#site_accounts_df["site_desc"] = site_accounts_df["site_desc"].map(bold_text)
#site_accounts_df["tr_summary"] = site_accounts_df["tr_summary"].map(bold_text)

# convert dataframe to feature set
site_accounts_fs = FeatureSet.from_dataframe(site_accounts_df)

# create dictionary with site description and tr summary that will be used to in the PUBLIC NHA layer after it is loaded with the updated NHA data
# site_account_dict = site_accounts.set_index('nha_join_id')[["site_desc", "tr_summary"]].apply(list,axis=1).to_dict()
# site_account_dict = {k: v for k, v in site_account_dict.items() if pd.notna(k) and k != ""}

##########################
## LOAD AND FORMAT SPECIES RECORDS
##########################
# Create Pandas dataframe from species table for records are not excluded
fields = ['EO_ID', 'taxa', 'species_url', 'nha_join_id', 'exclude']
species_sdf = pd.DataFrame((row for row in arcpy.da.SearchCursor(species_url, fields) if row[4] != "Y"), columns=fields)
# format NA values so they play nicely with ArcGIS
species_sdf = species_sdf.where(pd.notnull(species_sdf), None)

# create pandas dataframe from eo_ptreps layer
fields = ['EO_ID', 'SNAME', 'SCOMNAME', 'GRANK', 'SRANK', 'USESA', 'SPROT', 'PBSSTATUS', 'EORANK', 'SENSITV_SP', 'SENSITV_EO', 'LASTOBS_YR']
et_sdf = pd.DataFrame((row for row in arcpy.da.SearchCursor(eo_ptreps, fields)), columns=fields)

# join species table with eo_ptreps data by EO_ID
species_sdf = pd.merge(species_sdf, et_sdf, on='EO_ID', how='left')

# sort values by lastobs_yr and drop duplicate species by nha group
species_sdf = species_sdf.sort_values(['nha_join_id', 'LASTOBS_YR', 'SENSITV_EO'], ascending=[True, False, True])
species_sdf = species_sdf.drop_duplicates(subset=['nha_join_id', 'SNAME'], keep='first')

# add species_name column that includes combined species name and HTML tags to include bolding and italics
species_sdf['species_name'] = species_sdf['SCOMNAME'] + " (" + species_sdf['SNAME'] + ")"

# This is a dictionary of taxa photos. If photo path changes, then the paths need to change here.
taxa_dict = {
    "Salamander": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/2dc333723c544718841f2f5e88ff0499/data",
    "Frog": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/2dc333723c544718841f2f5e88ff0499/data",
    "Invertebrate - Spiders": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/d6df111318c345deaa86e6e84bf78b66/data",
    "Bird": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/af579794c0d542b8a8b03c08fe0ec170/data",
    "Invertebrate - Butterflies and Skippers": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/207673a6e65b46799eb338f6ae347060/data",
    "Invertebrate - Caddisflies": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/6110ce3f58e4445980d4b6f49b46e141/data",
    "Community": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/c1afe0edbd3a4affb5ac82507b762ecf/data",
    "Invertebrate - Crayfishes": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/4f1822fc34484e83a11d3c6e30c4c510/data",
    "Fish": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/c06622be569744729a794814d91f8ac8/data",
    "Mammal": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/e491f17747254ea699cfa03a02042431/data",
    "Invertebrate - Moths": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/e491f17747254ea699cfa03a02042431/data",
    "Invertebrate - Mussels": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/1e725033e46b4f379c911ae9b1827ef2/data",
    "Invertebrate - Dragonflies and Damselflies": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/1bf90bf5d2864f6e88fc762e01ca3a24/data",
    "Invertebrate - Other Beetles": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/8d8364bd189e46c39a72da770c18db1e/data",
    "Vascular Plant": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/e88df42c572344bbb82d43cda4c47d76/data",
    "Invertebrate - Gastropods": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/076e21399c064d53abb2f7a29434ae93/data",
    "Invertebrate - Sponges": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/30ea34f203f5437e853ee9b03b65453e/data",
    "Invertebrate - Tiger Beetles": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/e0cc2db8ffcf46b7a03d046820980b60/data",
    "Reptile": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/65f6f86875dd478b91fc1d5168c19415/data",
    "Invertebrate - Stoneflies": "https://wpcgis.maps.arcgis.com/sharing/rest/content/items/6110ce3f58e4445980d4b6f49b46e141/data"}

# join taxa_photo url with species dataframe based on taxa
species_sdf['taxa_photo'] = species_sdf['taxa'].map(taxa_dict)

# Deal with sensitive species by masking attributes if sensitive species or sensitive eo are marked Yes
species_sdf['species_name'] = np.where((species_sdf['SENSITV_SP'] == 'Y') | (species_sdf['SENSITV_EO'] == 'Y'), 'Sensitive Species', species_sdf['species_name'])
species_sdf['SCOMNAME'] = np.where((species_sdf['SENSITV_SP'] == 'Y') | (species_sdf['SENSITV_EO'] == 'Y'), 'Sensitive Species', species_sdf['SCOMNAME'])
species_sdf['SNAME'] = np.where((species_sdf['SENSITV_SP'] == 'Y') | (species_sdf['SENSITV_EO'] == 'Y'), '--', species_sdf['SNAME'])
species_sdf['GRANK'] = np.where((species_sdf['SENSITV_SP'] == 'Y') | (species_sdf['SENSITV_EO'] == 'Y'), '--', species_sdf['GRANK'])
species_sdf['SRANK'] = np.where((species_sdf['SENSITV_SP'] == 'Y') | (species_sdf['SENSITV_EO'] == 'Y'), '--', species_sdf['SRANK'])
species_sdf['SPROT'] = np.where((species_sdf['SENSITV_SP'] == 'Y') | (species_sdf['SENSITV_EO'] == 'Y'), '--', species_sdf['SPROT'])
species_sdf['PBSSTATUS'] = np.where((species_sdf['SENSITV_SP'] == 'Y') | (species_sdf['SENSITV_EO'] == 'Y'), '--', species_sdf['PBSSTATUS'])
species_sdf['taxa'] = np.where((species_sdf['SENSITV_SP'] == 'Y') | (species_sdf['SENSITV_EO'] == 'Y'), '--', species_sdf['taxa'])
species_sdf['species_url'] = np.where((species_sdf['SENSITV_SP'] == 'Y') | (species_sdf['SENSITV_EO'] == 'Y'), 'None', species_sdf['species_url'])
species_sdf['taxa_photo'] = np.where((species_sdf['SENSITV_SP'] == 'Y') | (species_sdf['SENSITV_EO'] == 'Y'), 'https://wpcgis.maps.arcgis.com/sharing/rest/content/items/459e3842241042858937219419dec559/data', species_sdf['taxa_photo'])

# Get final species dataframe that will be loaded into PUBLIC feature service
species_sdf = species_sdf[['species_name','SCOMNAME', 'SNAME', 'GRANK','SRANK','SPROT','PBSSTATUS','LASTOBS_YR','EORANK','taxa','taxa_photo','species_url','nha_join_id']]

# deal with field name mismatches and data type issues
species_sdf.rename(columns={'SCOMNAME':'scomname', 'SNAME':'sname', 'GRANK':'grank', 'SRANK':'srank', 'SPROT':'sprot', 'PBSSTATUS':'pbsstatus', 'LASTOBS_YR':'lastobs_yr', 'EORANK':'eorank'}, inplace=True)
species_sdf['lastobs_yr'] = species_sdf['lastobs_yr'].astype('Int64')

# convert dataframe to feature set
species_fs = FeatureSet.from_dataframe(species_sdf)

##########################
## LOAD TR BULLETS RECORDS
##########################

# create pandas dataframe from tr_bullets table
fields = ['threat_text', 'nha_join_id', 'threat_desc']
tr_bullets_sdf = pd.DataFrame((row for row in arcpy.da.SearchCursor(tr_bullets_url, fields)), columns=fields)
# format NA values so they play nicely with ArcGIS
tr_bullets_sdf = tr_bullets_sdf.where(pd.notnull(tr_bullets_sdf), None)

# italicize snames
tr_bullets_sdf["threat_text"] = tr_bullets_sdf["threat_text"].map(italicize_text)
#tr_bullets_sdf["threat_text"] = tr_bullets_sdf["threat_text"].map(bold_text)



# convert dataframe to feature set
tr_bullets_fs = FeatureSet.from_dataframe(tr_bullets_sdf)

##########################
## LOAD REFERENCE RECORDS
##########################

# create pandas dataframe from references table
fields = ['source_id', 'full_cite']
references_sdf = pd.DataFrame((row for row in arcpy.da.SearchCursor(nha_references_url, fields)), columns=fields)
# format NA values so they play nicely with ArcGIS
references_sdf = references_sdf.where(pd.notnull(references_sdf), None)

# convert dataframe to feature set
references_fs = FeatureSet.from_dataframe(references_sdf)

######################
## NOW WE ARE GOING TO CONNECT TO THE PUBLIC WEBGIS PORTAL AND START DELETING AND LOADING DATA
######################

# load wpc WEBGIS credentials from OS environment variables - these need to be setup in your operating system environment variables
wpc_webgis_username = os.environ.get("wpc_webgis_username")
wpc_gis_password = os.environ.get("wpc_gis_password")
wpc_webgis_username = "mmooreWPC"
# connect to Portal account
webgis = GIS('https://www.arcgis.com', wpc_webgis_username, wpc_gis_password)

###### this section deletes NHA polygons and appends current polygons to the Public NHA dataset
# delete all features from NHA Public layer
public_nha_flayer = FeatureLayer(PUBLIC_nha_url)
public_nha_flayer.delete_features(where="objectid > 0")

# append nha cores to public feature service layer
arcpy.env.maintainAttachments = True
arcpy.Append_management(nha_layer,PUBLIC_nha_url,"NO_TEST")


###### this section deletes SUSN polygons and appends current polygons to the Public SUSN dataset
# delete all features from SUSN Public layer
public_susn_flayer = FeatureLayer(PUBLIC_susns_url)
public_susn_flayer.delete_features(where="objectid > 0")

# append nha cores to public feature service layer
arcpy.env.maintainAttachments = True
arcpy.Append_management(susn_layer,PUBLIC_susns_url,"NO_TEST")

############
## DELETE AND LOAD IN SITE ACCOUNT RECORDS
############

# create public species feature layer
public_site_accounts_flayer = FeatureLayer(PUBLIC_site_accounts_url)
# delete species records from public feature layer
public_site_accounts_flayer.delete_features(where="objectid > 0")
# load species records from species feature set
public_site_accounts_flayer.edit_features(adds = site_accounts_fs)

# update the site description and tr summary in the public nha core layer with most recent entries in site account
with arcpy.da.UpdateCursor(PUBLIC_site_accounts_url,["site_desc","tr_summary"]) as cursor:
    for row in cursor:
        if row[0] is None:
            row[0] = "Site description is not yet databased for this site. Please see the Site Account PDF if available."
            cursor.updateRow(row)
        if row[1] is None:
            row[1] = "Threats and recommendations summary is not yet databased for this site. Please see the Site Account PDF if available."
            cursor.updateRow(row)

############
## DELETE AND LOAD IN SPECIES RECORDS
############
# create public species feature layer
public_species_flayer = FeatureLayer(PUBLIC_species_url)
# delete species records from public feature layer
public_species_flayer.delete_features(where="objectid > 0")
# load species records from species feature set
public_species_flayer.edit_features(adds = species_fs)

#######
## DELETE AND LOAD IN TR BULLETS
#######
# create public tr bullets layer
tr_bullets_flayer = FeatureLayer(PUBLIC_tr_bullets_url)
# delete all records from the public tr bullets table
tr_bullets_flayer.delete_features(where="objectid > 0")
# load tr bullet records from tr bullets feature set
tr_bullets_flayer.edit_features(adds = tr_bullets_fs)

#######
## DELETE AND LOAD IN NHA REFERENCES
#######
# create public references feature layer
references_flayer = FeatureLayer(PUBLIC_nha_references_url)
# delete all records from public references table
references_flayer.delete_features(where="objectid > 0")
# load references records from references feature set
references_flayer.edit_features(adds = references_fs)




#############
## DO ATTACHMENT DO DA TO GET ATTACHMENTS TRANSFERRED OVER TO PUBLIC FS DATA - this is a weird workaround because using
## append for hosted AGOL layers DOES NOT maintain attachments. So, instead, we are going to download all the pictures
## from our portal layer to a local folder, and then add the attachments from there.
#############
if attachments == "yes":
    # Create directory for photos if it doesn't already exist
    photo_path = r"C:/temp/nha_photos"
    shutil.rmtree(photo_path, ignore_errors=True)
    os.makedirs(photo_path, exist_ok=True)

    # export all attachments from NHA beta edit on GIS Portal
    arcpy.ExportAttachments_management(nha_url, photo_path, "", name_format = "REPLACE", name_fields = "nha_join_id")

    add_fields = ["photo_jpg", "photo_png", "photo_jpeg"]
    for f in add_fields:
        arcpy.AddField_management(nha_copy, f, "TEXT", "", "", 255)
    for f in add_fields:
        arcpy.AddField_management(susn_copy, f, "TEXT", "", "", 255)

    add_fields.append("nha_join_id")
    with arcpy.da.UpdateCursor(nha_copy, add_fields) as cursor:
        for row in cursor:
            if row[3] is not None:
                row[0] = row[3]+".jpg"
                row[1] = row[3]+".png"
                row[2] = row[3]+".jpeg"
                cursor.updateRow(row)

    with arcpy.da.UpdateCursor(susn_copy, add_fields) as cursor:
        for row in cursor:
            if row[3] is not None:
                row[0] = row[3]+".jpg"
                row[1] = row[3]+".png"
                row[2] = row[3]+".jpeg"
                cursor.updateRow(row)

    # add .png photos to public fs
    for f in add_fields:
        arcpy.AddAttachments_management(PUBLIC_nha_url, "nha_join_id", nha_copy, "nha_join_id", f, photo_path)
        arcpy.AddAttachments_management(PUBLIC_susns_url, "nha_join_id", susn_copy, "nha_join_id", f, photo_path)


############ THIS SECTION UPDATES THE NHA LAYER FOR DOMAIN THINGS
# with arcpy.da.UpdateCursor(PUBLIC_nha_url,"sig_rank") as cursor:
#     for row in cursor:
#         if row[0] is None:
#             pass
#         elif row[0] == "G":
#             row[0] = "Global"
#             cursor.updateRow(row)
#         elif row[0] == "R":
#             row[0] = "Regional"
#             cursor.updateRow(row)
#         elif row[0] == "S":
#             row[0] = "State"
#             cursor.updateRow(row)
#         elif row[0] == "L":
#             row[0] = "Local"
#             cursor.updateRow(row)
#         else:
#             row[0] = "Historic"
#             cursor.updateRow(row)

# with arcpy.da.UpdateCursor(PUBLIC_nha_url,["site_type"]) as cursor:
#     for row in cursor:
#         if row[0] is None:
#             pass
#         elif row[0] == "curr":
#             row[0] = "NHA - Current"
#             cursor.updateRow(row)
#         elif row[0] == "hist":
#             row[0] = "NHA - Historic"
#             cursor.updateRow(row)
#         elif row[0] == "susn":
#             row[0] = "SUSN - Species of Unusual Spatial Need"
#             cursor.updateRow(row)
#         else:
#             row[0] = None
#             cursor.updateRow(row)
