#-------------------------------------------------------------------------------
# Name:        NHA Tool 4.0
# Purpose:
# Author:      Molly Moore
# Created:     v3 created on 05/12/2019
# Updates:
# 2024-10-03 - updates being made to work with updated geodatabase and workflow
#-------------------------------------------------------------------------------

########################################################################################################################
## Import packages and define environment settings
########################################################################################################################

import arcpy,os,sys,string
from getpass import getuser
import sqlite3 as lite
import pandas as pd
import datetime
import arcgis
from arcgis import GIS
from arcgis.gis._impl._content_manager import SharingLevel

arcpy.env.overwriteOutput = True
arcpy.env.transferDomains = True

date = datetime.datetime.now().strftime("%Y-%m-%d")

########################################################################################################################
## Define universal variables and functions
########################################################################################################################

def element_type(elcode):
    """Takes ELCODE as input and returns NHA element type code."""
    if elcode.startswith('AAAA'):
        et = 'Salamander'
    elif elcode.startswith('AAAB'):
        et = 'Frog'
    elif elcode.startswith('AB'):
        et = 'Bird'
    elif elcode.startswith('AF'):
        et = 'Fish'
    elif elcode.startswith('AM'):
        et = 'Mammal'
    elif elcode.startswith('AR'):
        et = 'Reptile'
    elif elcode.startswith('C') or elcode.startswith('H'):
        et = 'Community'
    elif elcode.startswith('ICMAL'):
        et = 'Invertebrate - Crayfishes'
    elif elcode.startswith('ILARA'):
        et = 'Invertebrate - Spiders'
    elif elcode.startswith('IZSPN'):
        et = 'Invertebrate - Sponges'
    elif elcode.startswith('IICOL02'):
        et = 'Invertebrate - Tiger Beetles'
    elif elcode.startswith('IICOL'):
        et = 'Invertebrate - Other Beetles'
    elif elcode.startswith('IIEPH'):
        et = 'Invertebrate - Mayflies'
    elif elcode.startswith('IIHYM'):
        et = 'Invertebrate - Bees'
    elif elcode.startswith('IILEP'):
        et = 'Invertebrate - Butterflies and Skippers'
    elif elcode.startswith('IILEY') or elcode.startswith('IILEW') or elcode.startswith('IILEV') or elcode.startswith('IILEU'):
        et = 'Invertebrate - Moths'
    elif elcode.startswith('IIODO'):
        et = 'Invertebrate - Dragonflies and Damselflies'
    elif elcode.startswith('IIORT'):
        et = 'Invertebrate - Grasshoppers'
    elif elcode.startswith('IIPLE'):
        et = 'Invertebrate - Stoneflies'
    elif elcode.startswith('IITRI'):
        et = 'Invertebrate - Caddisflies'
    elif elcode.startswith('IMBIV'):
        et = 'Invertebrate - Mussels'
    elif elcode.startswith('IMGAS'):
        et = 'Invertebrate - Gastropods'
    elif elcode.startswith('I'):
        et = 'Invertebrate - Other'
    elif elcode.startswith('N'):
        et = 'Nonvascular Plant'
    elif elcode.startswith('P'):
        et = 'Vascular Plant'
    else:
        arcpy.AddMessage("Could not determine element type")
        et = None
    return et

# define function to update related global id field based on some other id field.
def update_rel_guid(parent_feature, primary_key, child_feature, foreign_key, related_guid):
    related_dict = {row[0]: row[1] for row in arcpy.da.SearchCursor(parent_feature, [primary_key, "GlobalID"]) if
                    row[0] is not None}
    with arcpy.da.UpdateCursor(child_feature, [foreign_key, related_guid]) as cursor:
        for row in cursor:
            for k, v in related_dict.items():
                if k == row[0]:
                    row[1] = v
                    cursor.updateRow(row)
                else:
                    pass

# define function to generate list of values with incremental indexes for given length
def generate_list(start_value, string, string2, length):
    return [f"{string}{i}{string2}" for i in range(start_value, start_value + length)]

########################################################################################################################
## Begin toolbox
########################################################################################################################

class Toolbox(object):
    def __init__(self):
        """Define the toolbox (the name of the toolbox is the name of the .pyt file)."""
        self.label = "NHA Tools v4"
        self.alias = "NHA Tools v4"
        self.canRunInBackground = False
        self.tools = [CreateNHAv3,ModifyNHA,SpeciesTransfer,FillAttributes,CalculateSiteRank,SiteNameLister,SiteAccountUploader]

########################################################################################################################
## Begin create NHA tool - this tool creates the core NHA from selected CPPs and fills initial attributes for the NHA
########################################################################################################################

class CreateNHAv3(object):
    def __init__(self):
        self.label = "1 Create New NHA"
        self.description = ""
        self.canRunInBackground = False

    def getParameterInfo(self):
        site_name = arcpy.Parameter(
            displayName = "Site Name",
            name = "site_name",
            datatype = "GPString",
            parameterType = "Required",
            direction = "Input")

        site_desc = arcpy.Parameter(
            displayName = "Brief Site Description",
            name = "site_desc",
            datatype = "GPString",
            parameterType = "Optional",
            direction = "Input")

        source_report = arcpy.Parameter(
            displayName = "Source Report",
            name = "source_report",
            datatype = "GPString",
            parameterType = "Optional",
            direction = "Input")
        source_report.value = r"None"

        cpp_core = arcpy.Parameter(
            displayName = "Selected CPP Core(s)",
            name = "cpp_core",
            datatype = "GPFeatureLayer",
            parameterType = "Required",
            direction = "Input")
        cpp_core.value = r'CPP Read Only\CPP Core'

        params = [site_name,site_desc,source_report,cpp_core]
        return params

    def isLicensed(self):
        return True

    def updateParameters(self, params):
        return

    def updateMessages(self, params):
        return

    def execute(self, params, messages):

        site_name = params[0].valueAsText
        site_desc = params[1].valueAsText
        source_report = params[2].valueAsText
        cpp_core = params[3].valueAsText

        nha_core = r'https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/0'

        # check to see if there is a selection on CPPs. If there isn't, error out
        desc = arcpy.Describe(cpp_core)
        if not desc.FIDSet == '':
            pass
        else:
            arcpy.AddWarning("No CPP Cores are selected. Please make a selection and try again.")
            sys.exit()

        # add reporting about whether NHA site name is a duplicate and error out if site name is already present in the gdb
        arcpy.AddMessage("............")
        nha_site_names = sorted({row[0] for row in arcpy.da.SearchCursor(nha_core,"SITE_NAME") if row[0] is not None})
        if not site_name in nha_site_names:
            arcpy.AddMessage("There are no existing NHAs with the same site name: "+site_name)
        else:
            arcpy.AddWarning("The NHA site name you have entered is not unique. Please enter a unique site name and try again.")
            sys.exit()


        arcpy.AddMessage("............")
        # create list of eo ids for all selected CPPs that are current or approved
        with arcpy.da.SearchCursor(cpp_core,["EO_ID","Status"]) as cursor:
            eoids = sorted({row[0] for row in cursor if row[1] != "n"})
        # create list of eo ids for all selected CPPs that are not approved
        with arcpy.da.SearchCursor(cpp_core,["EO_ID","Status"]) as cursor:
            excluded_eoids = sorted({row[0]for row in cursor if row[1] == "n"})

        # add reporting messages about which CPPs are being excluded
        if excluded_eoids:
            arcpy.AddMessage("Selected CPPs with the following EO IDs are being excluded because they were marked as not approved: "+ ','.join([str(x) for x in excluded_eoids]))
        else:
            pass

        # add reporting messages about which CPPs are being included and exit with message if no selected CPPs are current or approved.
        if len(eoids) != 0:
            arcpy.AddMessage("Selected CPPs with the following EO IDs are being used to create this NHA: "+','.join([str(x) for x in eoids]))
            arcpy.AddMessage("............")
        else:
            arcpy.AddWarning("Your CPP selection does not include any current or approved CPPs and we cannot proceed. Goodbye.")
            sys.exit()

        # create sql query based on number of CPPs included in query.
        if len(eoids) > 1:
            sql_query = '"EO_ID" in {}'.format(tuple(eoids))
        else:
            sql_query = '"EO_ID" = {}'.format(eoids[0])

        arcpy.AddMessage("Creating and attributing NHA core for site: "+ site_name)
        arcpy.AddMessage("............")
        # create cpp_core layer from selected CPPs marked as current or approved and dissolve to create temporary nha geometry
        cpp_core_lyr = arcpy.MakeFeatureLayer_management(cpp_core, "cpp_core_lyr", sql_query)
        temp_nha = arcpy.Dissolve_management(cpp_core_lyr, os.path.join("memory","temp_nha"))

        # get geometry token from nha
        with arcpy.da.SearchCursor(temp_nha,"SHAPE@") as cursor:
            for row in cursor:
                geom = row[0]

        # calculate NHA_JOIN_ID which includes network username and the next highest tiebreaker for that username padded to 6 places
        username = getuser().lower()
        where = '"nha_join_id" LIKE'+"'%{0}%'".format(username)
        with arcpy.da.SearchCursor(nha_core, 'nha_join_id', where_clause = where) as cursor:
            join_ids = sorted({row[0] for row in cursor})
        if len(join_ids) == 0:
            nha_join_id = username + '000001'
        else:
            t = join_ids[-1]
            tiebreak = str(int(t[-6:])+1).zfill(6)
            nha_join_id = username + tiebreak

        # test for unsaved edits - alert user to unsaved edits and end script
        try:
            # insert new NHA Core record
            values = [site_name,"curr",site_desc,"rev",datetime.date.today(),username,datetime.date.today(),source_report,nha_join_id,geom]
            fields = ["site_name","site_type","desc_","status","status_change_date","drawn_user","drawn_date","source_report","nha_join_id","SHAPE@"]
            with arcpy.da.InsertCursor(nha_core,fields) as cursor:
                cursor.insertRow(values)
        except RuntimeError:
            arcpy.AddWarning("You have unsaved edits in your NHA layer. Please save or discard edits and try again.")
            sys.exit()


########################################################################################################################
## Begin modify NHA tool - this tool archives the previous boundary, modifies the boundary of a selected NHA with selected
## CPP cores, and updates the current drawn notes
########################################################################################################################

class ModifyNHA(object):
    def __init__(self):
        self.label = "2 Modify Existing NHA"
        self.description = ""
        self.canRunInBackground = False

    def getParameterInfo(self):
        nha_cores = arcpy.Parameter(
            displayName="Selected NHA core to modify",
            name="nha_cores",
            datatype="GPFeatureLayer",
            parameterType="Required",
            direction="Input")

        cpp_core = arcpy.Parameter(
            displayName = "Selected CPP Core(s)",
            name = "cpp_core",
            datatype = "GPFeatureLayer",
            parameterType = "Required",
            direction = "Input")
        cpp_core.value = r'CPP Read Only\CPP Core'

        site_desc = arcpy.Parameter(
            displayName = "Brief Site Description - if updates are needed",
            name = "site_desc",
            datatype = "GPString",
            parameterType = "Optional",
            direction = "Input")

        source_report = arcpy.Parameter(
            displayName = "Source Report - if updates are needed",
            name = "source_report",
            datatype = "GPString",
            parameterType = "Optional",
            direction = "Input")
        source_report.value = r"None"

        params = [nha_cores,cpp_core,site_desc,source_report]
        return params

    def isLicensed(self):
        return True

    def updateParameters(self, params):
        return

    def updateMessages(self, params):
        return

    def execute(self, params, messages):

        nha_cores = params[0].valueAsText
        cpp_core = params[1].valueAsText
        site_desc = params[2].valueAsText
        source_report = params[3].valueAsText

        # NHA archive layer
        nha_archive = r"https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/0"

        # check for selection on nha core layer and exit if there is no selection or if more than 1 NHA is selected
        desc = arcpy.Describe(nha_cores)
        if desc.FIDSet == '':
            arcpy.AddError("No NHAs are selected. Please make a selection and try again.")
            sys.exit()
        if len((desc.FIDSet).split(';')) > 1:
            arcpy.AddError("More than one NHAs are selected. Please select only the NHA you wish to modify and try again.")
            sys.exit()
        else:
            pass

        # check for selection on cpp layer and exit if there is no selection
        desc = arcpy.Describe(cpp_core)
        if not desc.FIDSet == '':
            pass
        else:
            arcpy.AddWarning("No CPP Cores are selected. Please make a selection and try again.")
            sys.exit()

        # first we are going to archive the NHA
        archive_fields = ["site_name","site_type","desc_","status","status_change_date","status_change_reason","drawn_user",
                          "drawn_date","drawn_notes","review_user","review_date","review_notes","sig_rank","sig_rank_comm",
                          "project","source_report","site_pdf_link","wpc_blueprint","nha_join_id","SHAPE@"]
        #archive_rows = tuple(generate_list(0,"row[","]",len(archive_fields)))
        # get current NHA and insert it into the archive NHA layer
        with arcpy.da.SearchCursor(nha_cores,archive_fields) as cursor:
            for row in cursor:
                site_name = row[archive_fields.index("site_name")]
                nha_join_id = row[archive_fields.index("nha_join_id")]
                values = [row[0],row[1],row[2],row[3],row[4],row[5],row[6],row[7],row[8],row[9],row[10],row[11],row[12],
                          row[13],row[14],row[15],row[16],row[17],row[18],row[19]]
        with arcpy.da.InsertCursor(nha_archive,archive_fields) as cursor:
            cursor.insertRow(values)

        arcpy.AddMessage("............")
        # create list of eo ids for all selected CPPs that are current or approved
        with arcpy.da.SearchCursor(cpp_core,["EO_ID","Status"]) as cursor:
            eoids = sorted({row[0] for row in cursor if row[1] != "n"})
        # create list of eo ids for all selected CPPs that are not approved
        with arcpy.da.SearchCursor(cpp_core,["EO_ID","Status"]) as cursor:
            excluded_eoids = sorted({row[0]for row in cursor if row[1] == "n"})

        # add reporting messages about which CPPs are being excluded
        if excluded_eoids:
            arcpy.AddMessage("Selected CPPs with the following EO IDs are being excluded because they were marked as not approved: "+ ','.join([str(x) for x in excluded_eoids]))
        else:
            pass

        # add reporting messages about which CPPs are being included and exit with message if no selected CPPs are current or approved.
        if len(eoids) != 0:
            arcpy.AddMessage("Selected CPPs with the following EO IDs are being used to modify the geometry this NHA: "+','.join([str(x) for x in eoids]))
            arcpy.AddMessage("............")
        else:
            arcpy.AddWarning("Your CPP selection does not include any current or approved CPPs and we cannot proceed. Goodbye.")
            sys.exit()

        # create sql query based on number of CPPs included in query.
        if len(eoids) > 1:
            sql_query = '"EO_ID" in {}'.format(tuple(eoids))
        else:
            sql_query = '"EO_ID" = {}'.format(eoids[0])

        arcpy.AddMessage("Modifying and attributing the NHA core for site: "+ site_name)
        arcpy.AddMessage("............")
        # create cpp_core layer from selected CPPs marked as current or approved and dissolve to create temporary nha geometry
        cpp_core_lyr = arcpy.MakeFeatureLayer_management(cpp_core, "cpp_core_lyr", sql_query)
        temp_nha = arcpy.Dissolve_management(cpp_core_lyr, os.path.join("memory","temp_nha"))

        # get geometry token from nha
        with arcpy.da.SearchCursor(temp_nha,"SHAPE@") as cursor:
            for row in cursor:
                geom = row[0]

        # get username to fill drawn_user attribute
        username = getuser().lower()

        # test for unsaved edits - alert user to unsaved edits and end script
        try:
            # open editing session and update NHA Core record
            fields = ["status","status_change_date","drawn_user","drawn_date","SHAPE@"]
            if site_desc:
                fields = fields + ["desc_"]
            if source_report:
                fields = fields + ["source_report"]
            with arcpy.da.UpdateCursor(nha_cores,fields,where_clause="nha_join_id='{0}'".format(nha_join_id)) as cursor:
                for row in cursor:
                    row[0] = "rev"
                    row[1] = datetime.date.today()
                    row[2] = username
                    row[3] = datetime.date.today()
                    row[4] = geom
                    if site_desc:
                        row[5] = site_desc
                        cursor.updateRow(row)
                    if source_report and site_desc:
                        row[6] = source_report
                        cursor.updateRow(row)
                    elif source_report and not site_desc:
                        row[5] = source_report
                        cursor.updateRow(row)
                    cursor.updateRow(row)

        except RuntimeError:
            arcpy.AddWarning("You have unsaved edits in your NHA layer. Please save or discard edits and try again.")
            sys.exit()


######################################################################################################################################################
## Populate species list
######################################################################################################################################################

class SpeciesTransfer(object):
    def __init__(self):
        self.label = "3 Populate Species List - run every time there is an NHA boundary update."
        self.canRunInBackground = False
        self.description = """
        """

    def getParameterInfo(self):
        nha_cores = arcpy.Parameter(
            displayName="Selected NHA cores for which you want to populate EOs",
            name="nha_cores",
            datatype="GPFeatureLayer",
            parameterType="Required",
            direction="Input")

        eo_layer = arcpy.Parameter(
            displayName="EO Reps Polygon Layer (this tool will explode multipart EOs and use their centroids to reduce issues with large, low accuracy polygons)",
            name="eo_layer",
            datatype="GPFeatureLayer",
            parameterType="Required",
            direction="Input")

        params = [nha_cores, eo_layer]
        return params

    def isLicensed(self):
        return True

    def updateParameters(self, params):
        return

    def updateMessages(self, params):
        return

    def execute(self, params, messages):
        nha_cores = params[0].valueAsText
        eo_layer = params[1].valueAsText
        nha_species = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/6"

        # check for selection on nha core layer and exit if there is no selection
        desc = arcpy.Describe(nha_cores)
        if not desc.FIDSet == '':
            pass
        else:
            arcpy.AddWarning("No NHA Cores are selected. Please make a selection and try again.")
            sys.exit()

        # create list of NHA Join IDs for selected NHA cores
        with arcpy.da.SearchCursor(nha_cores,["nha_join_id"]) as cursor:
            nha_selected = sorted({row[0] for row in cursor})

        # we are going to make the eo polygons into single part centroids to tag to NHAs
        eo_singles = arcpy.MultipartToSinglepart_management(eo_layer, os.path.join("memory","eo_singles"))
        eo_centroids = arcpy.FeatureToPoint_management(eo_singles, os.path.join("memory","eo_centroids"),"INSIDE")
        eo_lyr = arcpy.MakeFeatureLayer_management(eo_centroids,"eo_lyr")

        # establish where clause to get list of qualifying EOs - this is the same as CPP query
        eo_where_clause = "(((((ELCODE LIKE 'P%' Or ELCODE LIKE 'N%' Or ELCODE LIKE 'C%' Or ELCODE LIKE 'H%' Or ELCODE LIKE 'G%') And LASTOBS_YR >= 1974) Or ((ELCODE LIKE 'P%' Or ELCODE LIKE 'N%') And (USESA = 'LE' Or USESA = 'LT') And LASTOBS_YR >= 1950)) Or (((ELCODE LIKE 'AF%' Or ELCODE LIKE 'AA%' Or ELCODE LIKE 'AR%') And LASTOBS_YR >= 1950) Or ELCODE = 'ARADE03011') Or ((ELCODE LIKE 'AB%' And LASTOBS_YR >= 1990) Or (ELCODE = 'ABNKC12060' And LASTOBS_YR >= 1980)) Or (((ELCODE LIKE 'AM%' Or ELCODE LIKE 'OBAT%') And ELCODE <> 'AMACC01150' And LASTOBS_YR >= 1970) Or (ELCODE = 'AMACC01100' And LASTOBS_YR >= 1950) Or (ELCODE = 'AMACC01150' And LASTOBS_YR >= 1985)) Or ((ELCODE LIKE 'IC%' Or ELCODE LIKE 'IIEPH%' Or ELCODE LIKE 'IITRI%' Or ELCODE LIKE 'IMBIV%' Or ELCODE LIKE 'IMGAS%' Or ELCODE LIKE 'IP%' Or ELCODE LIKE 'IZ%') And LASTOBS_YR >= 1950) Or (ELCODE LIKE 'I%' And ELCODE NOT LIKE 'IC%' And ELCODE NOT LIKE 'IIEPH%' And ELCODE NOT LIKE 'IITRI%' And ELCODE NOT LIKE 'IMBIV%' And ELCODE NOT LIKE 'IMGAS%' And ELCODE NOT LIKE 'IP%' And ELCODE NOT LIKE 'IZ%' And LASTOBS_YR >= 1980)) And LASTOBS <> 'NO DATE' And EORANK <> 'X' And EORANK <> 'X?' And EST_RA <> 'Low' And EST_RA <> 'Very Low' And EO_TRACK = 'Y')"
        # get list of EO IDs that qualify for CPP and qualify for inclusion in NHA
        with arcpy.da.SearchCursor(eo_layer,"EO_ID", eo_where_clause) as cursor:
            qualifying_eos = sorted({row[0] for row in cursor})

        # start loop of all selected nhas - each will be handled individually
        for nha in nha_selected:
            arcpy.AddMessage("Adding species for the following NHA: "+nha)
            # get global id and nha_join_id of parent NHA to fill related species records
            with arcpy.da.SearchCursor(nha_cores,["nha_join_id","GlobalID"], "nha_join_id = '{}'".format(nha)) as cursor:
                for row in cursor:
                    nha_join_id = row[0]
                    global_id = row[1]

            # get list of EOs that are already related to the selected NHA to skip over later if needed
            with arcpy.da.SearchCursor(nha_species,["nha_join_id","EO_ID"]) as cursor:
                eos_in_NHA = sorted({row[1] for row in cursor if row[0] == nha_join_id})

            # make feature layer from NHAs to allow for selection
            nha_lyr = arcpy.MakeFeatureLayer_management(nha_cores,"nha_lyr",where_clause="nha_join_id = '{}'".format(nha))

            # select all EO centroids that intersect the selected NHA
            arcpy.SelectLayerByLocation_management(eo_lyr,"INTERSECT",nha_lyr,"","NEW_SELECTION")

            with arcpy.da.SearchCursor(eo_lyr,"EO_ID") as cursor:
                intersecting_eos = sorted({row[0] for row in cursor})

            # use search cursor to get fields of selected EOs to get ready to insert them into species list
            eo_fields = ["EO_ID","ELCODE","SNAME","SCOMNAME","ELSUBID","LASTOBS_YR","SURVEY_YR","EO_TRACK","GRANK",
                         "SRANK","SPROT","USESA","PBSSTATUS","SENSITV_SP","SENSITV_EO","EORANK"]
            with arcpy.da.SearchCursor(eo_lyr,eo_fields) as cursor:
                for row in cursor:
                    eoid = row[0]
                    elcode = row[1]
                    sname = row[2]
                    scomname = row[3]
                    elsubid = row[4]
                    lastobs = row[5]
                    survey_yr = row[6]
                    eo_track = row[7]
                    grank = row[8]
                    srank = row[9]
                    sprot = row[10]
                    usesa = row[11]
                    pbsstatus = row[12]
                    sensitv_sp = row[13]
                    sensitv_eo = row[14]
                    eorank = row[15]
                    taxa_group = element_type(row[1])

                    if eoid in qualifying_eos:
                        exclude = "N"
                        exclude_reason = ""
                    else:
                        exclude = "Y"
                        exclude_reason = "EO does not qualify for inclusion in NHA because of tracking status, age, accuracy, or rank."

                    insert_fields = eo_fields+["exclude","exclude_reason","nha_join_id","nha_rel_GUID","taxa"]

                    # if eo id is not yet in the related table for the NHA, add it
                    if eoid not in eos_in_NHA:
                        insert_row = [eoid,elcode,sname,scomname,elsubid,lastobs,survey_yr,eo_track,grank,srank,sprot,usesa,
                                        pbsstatus,sensitv_sp,sensitv_eo,eorank,exclude,exclude_reason,nha_join_id,global_id,taxa_group]
                        with arcpy.da.InsertCursor(nha_species,insert_fields) as cursor:
                            cursor.insertRow(tuple(insert_row))
                    else:
                        pass
                    #arcpy.management.DeleteIdentical(nha_species, ["EO_ID", "nha_join_id"])

            # check for EOs listed in NHA that no longer exist or no longer intersect the boundary and mark them to be excluded
            for eo in eos_in_NHA:
                if eo in intersecting_eos:
                    pass
                else:
                    with arcpy.da.UpdateCursor(nha_species,["EO_ID","nha_join_id","exclude","exclude_reason"], where_clause="EO_ID = {0} AND nha_join_id = '{1}'".format(eo,nha_join_id)) as cursor:
                        for row in cursor:
                            row[2] = "Y"
                            row[3] = "EO centroid no longer exists or no longer intersects NHA boundary."
                            cursor.updateRow(row)


########################################################################################################################
## Begin fill nha spatial attributes tool which finishes attributes that depend on manual edits
########################################################################################################################

class FillAttributes(object):
    def __init__(self):
        """Define the tool (tool name is the name of the class)."""
        self.label = "4 Fill Related Attribute Tables (Protected Lands and Political Boundaries)"
        self.description = ""
        self.canRunInBackground = False

    def getParameterInfo(self):
        nha_core = arcpy.Parameter(
            displayName = "Selected NHA Core Layer",
            name = "nha_core",
            datatype = "GPFeatureLayer",
            parameterType = "Required",
            direction = "Input")
        nha_core.value = r'NHA Beta EDIT\Natural Heritage Areas'

        params = [nha_core]
        return params

    def isLicensed(self):
        return True

    def updateParameters(self, params):
        return

    def updateMessages(self, params):
        return

    def execute(self, params, messages):

        nha_core = params[0].valueAsText

        # define paths
        muni = r'https://gis.waterlandlife.org/server/rest/services/Boundaries/FeatureServer/2'
        prot_lands = r'https://gis.waterlandlife.org/server/rest/services/BaseLayers/We_Conserve_PA_Protected_Lands/FeatureServer/0'
        prot_lands_tbl = r'https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/3'
        boundaries_tbl = r'https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/2'

        # check for selection on nha core layer and exit if there is no selection
        desc = arcpy.Describe(nha_core)
        if not desc.FIDSet == '':
            pass
        else:
            arcpy.AddWarning("No NHA Cores are selected. Please make a selection and try again.")
            sys.exit()

        # create list of NHA Join IDs for selected NHA cores
        with arcpy.da.SearchCursor(nha_core,["NHA_JOIN_ID"]) as cursor:
            nha_selected = sorted({row[0] for row in cursor})

        # make feature layer from municipal layer
        muni_lyr = arcpy.MakeFeatureLayer_management(muni,"muni_lyr")

        # start loop to attribute each selected nha
        for nha in nha_selected:
            arcpy.AddMessage("Attributing NHA Core: "+nha)
            arcpy.AddMessage("......")
            # delete previous records in boundaries table if they have same NHA Join ID
            with arcpy.da.UpdateCursor(boundaries_tbl,["NHA_JOIN_ID"]) as cursor:
                for row in cursor:
                    if row[0] == nha:
                        cursor.deleteRow()
            # delete previous records in protected lands table if they have same NHA Join ID
            with arcpy.da.UpdateCursor(prot_lands_tbl,["NHA_JOIN_ID"]) as cursor:
                for row in cursor:
                    if row[0] == nha:
                        cursor.deleteRow()

            # make feature layer of nha join id in loop
            sql_query = "NHA_JOIN_ID = '{}'".format(nha)
            nha_core_lyr = arcpy.MakeFeatureLayer_management(nha_core, "nha_core_lyr", sql_query)

            # attribute political boundaries table
            # attribute the counties and municipalities based on those that intersect the nha
            arcpy.SelectLayerByLocation_management(muni_lyr,"INTERSECT",nha_core_lyr,selection_type="NEW_SELECTION")
            MuniInsert = []
            with arcpy.da.SearchCursor(muni_lyr,["COUNTY_NAM","MUNICIPA_1"]) as cursor:
                for row in cursor:
                    values = tuple([row[0].title(),row[1].title(),nha])
                    MuniInsert.append(values)
            arcpy.AddMessage(nha + " Boundaries: ")
            for insert in MuniInsert:
                with arcpy.da.InsertCursor(boundaries_tbl,["county","municipality","nha_join_id"]) as cursor:
                    arcpy.AddMessage(insert)
                    cursor.insertRow(insert)
            # fill related globalid field to establish official relationship
            update_rel_guid(nha_core_lyr, "nha_join_id", boundaries_tbl, "nha_join_id", "nha_rel_GUID")
            arcpy.AddMessage("......")

            ## attribute protected lands table
            # tabulate intersection to get percent and name of protected land that overlaps nha
            tab_area = arcpy.TabulateIntersection_analysis(nha_core_lyr,arcpy.Describe(nha_core_lyr).OIDFieldName,prot_lands,os.path.join("memory","tab_area"),["sitename","loc_own"])
            # insert name and percent overlap of protected lands
            ProtInsert = []
            with arcpy.da.SearchCursor(tab_area,["sitename","loc_own","PERCENTAGE"]) as cursor:
                for row in cursor:
                    values = tuple([row[0],row[1],round(row[2],2),nha])
                    ProtInsert.append(values)
            arcpy.AddMessage(nha+ " Protected Lands: ")
            if ProtInsert:
                for insert in ProtInsert:
                    with arcpy.da.InsertCursor(prot_lands_tbl,["protected_land","owner","type","nha_join_id"]) as cursor:
                        arcpy.AddMessage(insert)
                        cursor.insertRow(insert)
                update_rel_guid(nha_core_lyr, "nha_join_id", prot_lands_tbl, "nha_join_id", "nha_rel_GUID")
            else:
                arcpy.AddMessage("No protected lands overlap the NHA core.")
            arcpy.AddMessage("#########################################################")
            arcpy.AddMessage("#########################################################")


######################################################################################################################################################
## Calculate Site Rank
######################################################################################################################################################

class CalculateSiteRank(object):
    def __init__(self):
        """Define the tool (tool name is the name of the class)."""
        self.label = "5 Calculate Site Rank"
        self.description = ""
        self.canRunInBackground = False

    def getParameterInfo(self):
        nha_core = arcpy.Parameter(
            displayName = "Selected NHA Core Layer",
            name = "nha_core",
            datatype = "GPFeatureLayer",
            parameterType = "Required",
            direction = "Input")
        nha_core.value = r'NHA Beta EDIT\Natural Heritage Areas'

        params = [nha_core]
        return params

    def isLicensed(self):
        return True

    def updateParameters(self, params):
        return

    def updateMessages(self, params):
        return

    def execute(self, params, messages):
        nha_core = params[0].valueAsText

        nha_species = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/6"
        rounded_grank = r"https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/3"
        rounded_srank = r"https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/4"
        nha_rank_matrix = r"https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/2"
        eorank_weights = r"https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/1"

        # check for selection on nha core layer and exit if there is no selection
        desc = arcpy.Describe(nha_core)
        if not desc.FIDSet == '':
            pass
        else:
            arcpy.AddWarning("No NHA Cores are selected. Please make a selection and try again.")
            sys.exit()

        # define function to convert arcgis table to Pandas dataframe
        def arcgis_table_to_pandas_df(table_path, field_names):
            arr = arcpy.da.TableToNumPyArray(table_path, field_names)
            return pd.DataFrame(arr)

        # create Pandas dataframes from NHA species list and reference tables
        species_df = arcgis_table_to_pandas_df(nha_species,["EO_ID","SNAME","SCOMNAME","ELSUBID","GRANK","SRANK","EORANK","exclude","nha_join_id"])
        grank_df = arcgis_table_to_pandas_df(rounded_grank,["grank","grank_rounded"])
        srank_df = arcgis_table_to_pandas_df(rounded_srank,["srank","srank_rounded"])
        nha_matrix_df = arcgis_table_to_pandas_df(nha_rank_matrix,["grank","srank","combinedrank","score"])
        eorank_df = arcgis_table_to_pandas_df(eorank_weights,["eorank","weight"])

        # do a bunch of joins to get combined grank/srank scores and eo weights into the species list
        species_df = pd.merge(species_df, grank_df, how='left', left_on="GRANK", right_on="grank")
        species_df = pd.merge(species_df, srank_df, how='left', left_on="SRANK", right_on="srank")
        species_df['combinedrank'] = species_df["grank_rounded"]+species_df["srank_rounded"]
        species_df = pd.merge(species_df, nha_matrix_df[["combinedrank","score"]], how='left', left_on="combinedrank", right_on="combinedrank")
        species_df.score = pd.to_numeric(species_df["score"]).fillna(0)
        species_df = pd.merge(species_df, eorank_df, how='left', left_on="EORANK", right_on="eorank")
        species_df["weighted_score"] = species_df["score"]*species_df["weight"]

        # create list of NHA Join IDs for selected NHA cores
        with arcpy.da.SearchCursor(nha_core,["NHA_JOIN_ID"]) as cursor:
            nha_selected = sorted({row[0] for row in cursor})

        # loop through all nha_join_ids that are selected
        for nha in nha_selected:
            arcpy.AddMessage("Calculating site rank for: "+nha)
            # create dataframe of species in NHA that qualify for inclusion
            nha_species_df = species_df[(species_df['nha_join_id']==nha) & (species_df['exclude']=="N")]
            site_score = nha_species_df["weighted_score"].sum() # sum the weighted score for each NHA
            if site_score > 457:
                site_rank = "G"
            elif 152 < site_score <= 457:
                site_rank = "R"
            elif 0 < site_score <= 152:
                site_rank = "S"
            else:
                site_rank = "L"

            # create global override lists
            global_override = ["G1","G2"]
            regional_override = ["G3"]

            # if site contains any G1 or G2 species, they should automatically be given a Global site value
            global_override = nha_species_df["grank_rounded"].isin(global_override).any()
            # if site contains G3 species, they should automatically be given a Global site value
            regional_override = nha_species_df["grank_rounded"].isin(regional_override).any()

            if global_override == True:
                site_rank = "G"
            elif regional_override == True:
                site_rank = "R"
            else:
                pass

            # update site rank in NHA core layer
            with arcpy.da.UpdateCursor(nha_core,["nha_join_id","sig_rank"],where_clause="nha_join_id = '{0}'".format(nha)) as cursor:
                for row in cursor:
                    if row[0] == nha:
                        row[1] = site_rank
                        cursor.updateRow(row)


######################################################################################################################################################
## Site Name Lister
######################################################################################################################################################

class SiteNameLister(object):
    def __init__(self):
        """Define the tool (tool name is the name of the class)."""
        self.label = "Site Name Lister"
        self.description = ""
        self.canRunInBackground = False
        self.category = "Site Report Helpers"

    def getParameterInfo(self):
        nha_core = arcpy.Parameter(
            displayName = "Selected NHA Core Layer",
            name = "nha_core",
            datatype = "GPFeatureLayer",
            parameterType = "Required",
            direction = "Input")
        nha_core.value = r'NHA Beta EDIT\Natural Heritage Areas'

        params = [nha_core]
        return params

    def isLicensed(self):
        return True

    def updateParameters(self, params):
        return

    def updateMessages(self, params):
        return

    def execute(self, params, messages):
        nha_core = params[0].valueAsText

        # check for selection on nha core layer and exit if there is no selection
        desc = arcpy.Describe(nha_core)
        if not desc.FIDSet == '':
            pass
        else:
            arcpy.AddWarning("No NHA Cores are selected. Please make a selection and try again.")
            sys.exit()

        # get list of selected NHA site names to feed into R site report generator script
        with arcpy.da.SearchCursor(nha_core,"site_name") as cursor:
            site_names = sorted({row[0] for row in cursor})

        arcpy.AddMessage(tuple(site_names))

######################################################################################################################################################
## Site Account Uploader - This tool takes selected NHAs, looks for site reports, and adds them or updates them on the Portal if there is a newer version available.
######################################################################################################################################################

class SiteAccountUploader(object):
    def __init__(self):
        """Define the tool (tool name is the name of the class)."""
        self.label = "Site Account Uploader"
        self.description = "This tool takes selected NHAs, looks for site reports, and adds them or updates them on the Portal if there is a newer version available."
        self.canRunInBackground = False
        self.category = "Site Report Helpers"

    def getParameterInfo(self):
        nha_core = arcpy.Parameter(
            displayName = "Selected NHA Core Layer",
            name = "nha_core",
            datatype = "GPFeatureLayer",
            parameterType = "Required",
            direction = "Input")
        nha_core.value = r'NHA Beta EDIT\Natural Heritage Areas'

        params = [nha_core]
        return params

    def isLicensed(self):
        return True

    def updateParameters(self, params):
        return

    def updateMessages(self, params):
        return

    def execute(self, params, messages):
        nha_core = params[0].valueAsText

        # check for selection on nha core layer and exit if there is no selection
        desc = arcpy.Describe(nha_core)
        if not desc.FIDSet == '':
            pass
        else:
            arcpy.AddWarning("No NHA Cores are selected. Please make a selection and try again.")
            sys.exit()

        # load gis credentials from OS environment variables - these need to be setup in your operating system environment variables
        wpc_gis_username = os.environ.get("wpc_webgis_username")
        wpc_gis_password = os.environ.get("wpc_gis_password")
        # connect to Portal account
        gis = GIS('https://webgis.waterlandlife.org/portal', wpc_gis_username, wpc_gis_password)

        # define path where site reports are held - THESE NEED TO CHANGE IF THE PATHS CHANGE!!!!
        site_report_dir = r"H:\Scripts\NHA_Tools\SiteReports\_data\output"
        site_folder = gis.content.folders.get(folder="NHA Site Reports")

        # get list of nha_join_ids for selected nhas
        with arcpy.da.UpdateCursor(nha_core,["nha_join_id","site_name","site_pdf_link"]) as cursor:
            for row in cursor:
                nha_join_id = row[0] # get nha_join_id for record
                site_name = row[1] # get site_name for record

                # get list of files in local site_report_directory to see if there are any ready to upload
                files = [f for f in os.listdir(site_report_dir) if os.path.isfile(os.path.join(site_report_dir, f)) if f.split("_")[-1][0:-4] == nha_join_id]
                # if there aren't any, pass and move on to the next one
                if len(files) == 0:
                    arcpy.AddMessage("No PDF site account is present for: "+nha_join_id+". We have nothing to update, so we're moving on to the next one.")
                    pass
                else:
                    file = files[-1] # use this to get the most recent site report

                    # see if this site account is already uploaded
                    site_match = gis.content.search(query="title:" + files[-1][0:-4])
                    # if there is already a site account with the same filename, skip it. otherwise, move on
                    if len(site_match) > 0:
                        arcpy.AddMessage(
                            "There is already a file of exactly the same name for : " + nha_join_id + ". We have nothing to update, so we're moving on to the next one.")
                        pass
                    else:
                        # if there are site accounts that match the nha_join_id, delete them! because we are uploading a more current version
                        site_del = gis.content.search(query="title:" + nha_join_id)
                        # DELETE SITE ACCOUNTS
                        for item in site_del:
                            item.delete()
                        # now we will upload new site account to NHA Site Reports portal folder
                        # first set item properties to record metadata - fill more of this in later
                        nha_item_properties = arcgis.gis.ItemProperties(
                            item_type="PDF",
                            title=file[0:-4],
                            description="NHA Site Account PDF for "+site_name+" uploaded on "+date+"."
                        )

                        # get file path and add file to NHA Site Report folder on the portal
                        upload_file = os.path.join(site_report_dir, file)
                        site_item = site_folder.add(item_properties = nha_item_properties, file = upload_file).result()
                        # update sharing to PUBLIC using the sharing manager
                        sharing_mgr = site_item.sharing
                        sharing_mgr.sharing_level = SharingLevel.EVERYONE

                        # get item id to use to build pdf url
                        item_id = site_item.id
                        site_account_url = r"https://webgis.waterlandlife.org/portal/sharing/rest/content/items/"+item_id+r"/data"

                        # update pdf site account url in feature service
                        row[2] = site_account_url
                        cursor.updateRow(row)


######################################################################################################################################################
## NHA Export Tool
######################################################################################################################################################

class NHAExport(object):
    def __init__(self):
        """Define the tool (tool name is the name of the class)."""
        self.label = "Export NHAs to File Geodatabase"
        self.description = ""
        self.canRunInBackground = False
        self.category = "NHA Export Tools"

    def getParameterInfo(self):
        nha_core = arcpy.Parameter(
            displayName = "Selected NHA Core Layer",
            name = "nha_core",
            datatype = "GPFeatureLayer",
            parameterType = "Required",
            direction = "Input")
        nha_core.value = r'NHAEdit\NHA Core Habitat'

        output_gdb = arcpy.Parameter(
            displayName = "Export File Geodatabase Location and Name",
            name = "output_gdb",
            datatype = "DEWorkspace",
            parameterType = "Required",
            direction = "Output")

        nha_query = arcpy.Parameter(
            displayName = "What NHA statuses would you like to include in export?",
            name = "nha_query",
            datatype = "GPString",
            parameterType = "Required",
            direction = "Input")
        nha_query.filter.list = ["Only Current NHAs","Current and Historic NHAs","All Current, Historic, and SUSNs"]
        nha_query.value = "Only Current NHAs"

        sensitive_species = arcpy.Parameter(
            displayName = "What do you want to do with sensitive species?",
            name = "sensitive_species",
            datatype = "GPString",
            parameterType = "Required",
            direction = "Input")
        sensitive_species.filter.list = ["Include sensitive species in species table","Mask sensitive species in species table","Exclude species table from export"]
        sensitive_species.value = "Include sensitive species in species table"

        params = [nha_core,output_gdb,nha_query,sensitive_species]
        return params

    def isLicensed(self):
        return True

    def updateParameters(self, params):
        return

    def updateMessages(self, params):
        return

    def execute(self, params, messages):
        nha_core = params[0].valueAsText
        output_gdb = params[1].valueAsText
        nha_query = params[2].valueAsText
        sensitive_species = params[3].valueAsText

        eo_url = r'https://gis.waterlandlife.org/server/rest/services/PNHP/Biotics_READ_ONLY/FeatureServer/0'
        species_url = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/6"

        #check for selection. error out if no selection is made.
        desc = arcpy.Describe(nha_core)
        if not desc.FIDSet == '':
            pass
        else:
            arcpy.AddWarning("No NHA Cores are selected. Please make a selection and try again.")
            sys.exit()

        #create empty database
        arcpy.AddMessage("Creating Database")
        arcpy.CreateFileGDB_management(os.path.dirname(output_gdb),os.path.basename(output_gdb)+".gdb")

        #create list of qualifying NHA_JOIN_IDs to be exported in selection based on selection of current or completed not published
        with arcpy.da.SearchCursor(nha_core,["nha_join_id","site_type"]) as cursor:
            if nha_query == "Only Current NHAs":
                nha_ids = sorted({row[0] for row in cursor if row[0] is not None and row[1] == 'curr'})
            elif nha_query == "Current and Historic NHAs":
                nha_ids = sorted({row[0] for row in cursor if row[0] is not None and (row[1] == 'curr' or row[1] == 'hist')})
            else:
                nha_ids = sorted({row[0] for row in cursor if row[0] is not None and (row[1] == 'curr' or row[1] == 'hist' or row[1] == 'susn')})

        #construct where query for feature set load statements
        nha_expression = "nha_join_id IN ({0})".format(','.join("'{0}'".format(id) for id in nha_ids))
        species_expression = "nha_join_id IN ({0}) AND exclude = 'N'".format(','.join("'{0}'".format(id) for id in nha_ids))

        #load qualifying core NHAs to feature set and save in output file gdb
        arcpy.AddMessage("Copying Selected NHA Cores")

        # use fieldmap to remove unwanted fields
        fieldmappings = arcpy.FieldMappings()
        # Add all fields from inputs.
        fieldmappings.addTable(nha_core)
        # Name fields you want to delete.
        keep_fields = ["site_name","desc_","sig_rank","nha_join_id"]
        # Remove all output fields you don't want.
        for field in fieldmappings.fields:
            if field.name not in keep_fields:
                fieldmappings.removeFieldMap(fieldmappings.findFieldMapIndex(field.name))

        core = arcpy.FeatureClassToFeatureClass_conversion(nha_core,output_gdb+".gdb","NHA_Core",nha_expression,fieldmappings)

        # check if species table should be copied
        if sensitive_species == "Exclude species table from export":
            arcpy.AddMessage("You have chosen not to include the species table in your export")
            pass
        else:
            #load qualifying species table records and save to output gdb
            arcpy.AddMessage("Copying Species Table")

            # use fieldmap to remove unwanted fields
            fieldmappings = arcpy.FieldMappings()
            # Add all fields from inputs.
            fieldmappings.addTable(species_url)
            # Name fields you want to delete.
            keep_fields = ["EO_ID", "SNAME", "SCOMNAME", "LASTOBS_YR", "SURVEY_YR", "GRANK", "SRANK", "SPROT", "USESA", "PBSSTATUS", "nha_join_id"]  # etc.
            # Remove all output fields you don't want.
            for field in fieldmappings.fields:
                if field.name not in keep_fields:
                    fieldmappings.removeFieldMap(fieldmappings.findFieldMapIndex(field.name))

            arcpy.TableToTable_conversion(species_url,output_gdb+".gdb","SpeciesTable",species_expression,fieldmappings)

            #create relationship class between nha core and species table
            arcpy.CreateRelationshipClass_management(os.path.join(output_gdb+".gdb","NHA_Core"),os.path.join(output_gdb+".gdb","SpeciesTable"),os.path.join(output_gdb+".gdb","NHA_Core_TO_Species"),"SIMPLE","Core_TO_Species","Species_TO_Core","NONE","ONE_TO_MANY","NONE","NHA_JOIN_ID","NHA_JOIN_ID")

            #check if sensitive species should be masked
            if sensitive_species == "Mask sensitive species in species table":
                #load eo_ptreps into feature set
                eo_ptreps = arcpy.FeatureSet()
                eo_ptreps.load(eo_url)
                #create list of sensitive species and sensitive eos
                with arcpy.da.SearchCursor(eo_ptreps,["EO_ID","SENSITV_SP","SENSITV_EO"]) as cursor:
                    sensitive_eos = sorted({row[0] for row in cursor if row[1]=="Y" or row[2]=="Y"})
                #edit sensitive species records to scrub identifying info
                with arcpy.da.UpdateCursor(os.path.join(output_gdb+".gdb","SpeciesTable"),["EO_ID", "SNAME", "SCOMNAME", "LASTOBS_YR", "SURVEY_YR", "GRANK", "SRANK", "SPROT", "USESA", "PBSSTATUS", "nha_join_id"]) as cursor:
                    for row in cursor:
                        if row[0] in sensitive_eos:
                            row[0] = None
                            row[1] = "SENSITIVE SPECIES"
                            row[2] = "SENSITIVE SPECIES"
                            row[3] = None
                            row[4] = None
                            row[5] = None
                            row[6] = None
                            row[7] = None
                            row[8] = None
                            row[9] = None
                            cursor.updateRow(row)
                        else:
                            pass
            else:
                arcpy.AddMessage("You have chosen not to mask sensitive species")

            arcpy.JoinField_management(os.path.join(output_gdb+".gdb","SpeciesTable"),"nha_join_id",core,"nha_join_id",["site_name"])