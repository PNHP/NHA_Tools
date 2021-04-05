#-------------------------------------------------------------------------------
# Name:        NHA Tool 3.0
# Purpose:
# Author:      Molly Moore
# Created:     05/12/2019
#-------------------------------------------------------------------------------

######################################################################################################################################################
## Import packages and define environment settings
######################################################################################################################################################

import arcpy,os,sys,string
from getpass import getuser
import sqlite3 as lite
import pandas as pd

arcpy.env.overwriteOutput = True
arcpy.env.transferDomains = True

######################################################################################################################################################
## Define universal variables and functions
######################################################################################################################################################

exceptions = ["SW","SE","NW","NE","US","PA"]

def get_attribute(in_fc, select_fc, field):
    """Takes an input feature class that intersects the select_fc and returns
    attributes in the specified field. Attributes are returned as a string, that
    can then be added to another feature class attribute table."""
    in_fc_lyr = arcpy.MakeFeatureLayer_management(in_fc, "in_fc_lyr")
    arcpy.SelectLayerByLocation_management("in_fc_lyr", "INTERSECT", select_fc)
    with arcpy.da.SearchCursor(in_fc_lyr,field) as cursor:
        attribute_list = sorted({row[0] for row in cursor})
    final_attributes = []
    for string in attribute_list:
        f = " ".join([word.title() if word not in exceptions else word for word in string.split(" ")])
        final_attributes.append(f)
    return ", ".join([str(x) for x in final_attributes])

def element_type(elcode):
    """Takes ELCODE as input and returns NHA element type code."""
    if elcode.startswith('AAAA'):
        et = 'AAAA'
    elif elcode.startswith('AAAB'):
        et = 'AAAB'
    elif elcode.startswith('AB'):
        et = 'AB'
    elif elcode.startswith('AF'):
        et = 'AF'
    elif elcode.startswith('AM'):
        et = 'AM'
    elif elcode.startswith('AR'):
        et = 'AR'
    elif elcode.startswith('C') or elcode.startswith('H'):
        et = 'CGH'
    elif elcode.startswith('ICMAL'):
        et = 'ICMAL'
    elif elcode.startswith('ILARA'):
        et = 'ILARA'
    elif elcode.startswith('IZSPN'):
        et = 'IZSPN'
    elif elcode.startswith('IICOL02'):
        et = 'IICOL02'
    elif elcode.startswith('IICOL'):
        et = 'IICOL'
    elif elcode.startswith('IIEPH'):
        et = 'IIEPH'
    elif elcode.startswith('IIHYM'):
        et = 'IIHYM'
    elif elcode.startswith('IILEP'):
        et = 'IILEP'
    elif elcode.startswith('IILEY') or elcode.startswith('IILEW') or elcode.startswith('IILEV') or elcode.startswith('IILEU'):
        et = 'IILEY'
    elif elcode.startswith('IIODO'):
        et = 'IIODO'
    elif elcode.startswith('IIORT'):
        et = 'IIORT'
    elif elcode.startswith('IIPLE'):
        et = 'IIPLE'
    elif elcode.startswith('IITRI'):
        et = 'IITRI'
    elif elcode.startswith('IMBIV'):
        et = 'IMBIV'
    elif elcode.startswith('IMGAS'):
        et = 'IMGAS'
    elif elcode.startswith('I'):
        et = 'I'
    elif elcode.startswith('N'):
        et = 'N'
    elif elcode.startswith('P'):
        et = 'P'
    else:
        arcpy.AddMessage("Could not determine element type")
        et = None
    return et

######################################################################################################################################################
## Begin toolbox
######################################################################################################################################################

class Toolbox(object):
    def __init__(self):
        """Define the toolbox (the name of the toolbox is the name of the .pyt file)."""
        self.label = "NHA Tools v3"
        self.alias = "NHA Tools v3"
        self.canRunInBackground = False
        self.tools = [CreateNHAv3,FillAttributes,SiteRankFill,NHAExport]

######################################################################################################################################################
## Begin create NHA tool - this tool creates the core and supporting NHAs and fills their initial attributes
######################################################################################################################################################

class CreateNHAv3(object):
    def __init__(self):
        self.label = "1 Create NHA - Version 3"
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
            displayName = "Site Description",
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
        cpp_core.value = r'CPP\CPP Core'

        cpp_supporting = arcpy.Parameter(
            displayName = "CPP Supporting Layer",
            name = "cpp_supporting",
            datatype = "GPFeatureLayer",
            parameterType = "Required",
            direction = "Input")
        cpp_supporting.value = r"CPP\CPP Supporting"

        arcmap = arcpy.Parameter(
            displayName = "Check box if you are using ArcMap 10.xx instead of ArcGIS Pro.",
            name = "arcmap",
            datatype = "GPBoolean",
            parameterType = "optional",
            direction = "Input")

        params = [site_name,site_desc,source_report,cpp_core,cpp_supporting,arcmap]
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
        cpp_supporting = params[4].valueAsText
        arcmap = params[5].valueAsText

        # set in_memory or memory workspace depending on whether using Pro or ArcMap
        if str(arcmap) == 'true':
            mem_workspace = "in_memory"
        else:
            mem_workspace = "memory"

##        site_name = "TEST_MMOORE"
##        site_desc = ""
##        source_report = "BLOOP"
##        cpp_core = r"PNHP\\CPP\\CPP Core"
##        cpp_supporting = "CPP\\CPP Supporting"
##
##        nha_core = r"H:\\Projects\\NHA\\_NHA_Updates_2019_12_05\\NHA.gdb\\NHA_Core"
##        nha_supporting = r"H:\\Projects\\NHA\\_NHA_Updates_2019_12_05\\NHA.gdb\\NHA_Supporting"
##        spec_tbl = r"H:\\Projects\\NHA\\_NHA_Updates_2019_12_05\\NHA.gdb\\NHA_SpeciesTable"

##        nha_core = r'https://maps.waterlandlife.org/arcgis/rest/services/PNHP/NHAEdit/FeatureServer/0'
##        nha_supporting = r'https://maps.waterlandlife.org/arcgis/rest/services/PNHP/NHAEdit/FeatureServer/1'
##        spec_tbl = r'https://maps.waterlandlife.org/arcgis/rest/services/PNHP/NHAEdit/FeatureServer/4'

        nha_core = r'NHAEdit\NHA Core Habitat'
        nha_supporting = r'NHAEdit\NHA Supporting Landscape'
        spec_tbl = r'PNHP.DBO.NHA_SpeciesTable'

        eo_reps = r'W:\\Heritage\\Heritage_Data\\Biotics_datasets.gdb\\eo_reps'

######################################################################################################################################################
## create NHA Core shape and get NHA Core attributes
######################################################################################################################################################

        desc = arcpy.Describe(cpp_core)
        if not desc.FIDSet == '':
            pass
        else:
            arcpy.AddWarning("No CPP Cores are selected. Please make a selection and try again.")
            sys.exit()

        desc = arcpy.Describe(nha_core)
        if not desc.FIDSet == '':
            arcpy.AddWarning("There is currently a selection on the NHA Core layer. Please clear the selection and try again.")
            sys.exit()
        else:
            pass

        arcpy.AddMessage("......")
        # create list of eo ids for all selected CPPs that are current or approved
        with arcpy.da.SearchCursor(cpp_core,["EO_ID","Status"]) as cursor:
            eoids = sorted({row[0] for row in cursor if row[1] != "n"})
        # create list of eo ids for all selected CPPs that are not approved
        with arcpy.da.SearchCursor(cpp_core,["EO_ID","Status"]) as cursor:
            excluded_eoids = sorted({row[0]for row in cursor if row[1] == "n"})

        # add reporting messages about which CPPs are being excluded
        if excluded_eoids:
            arcpy.AddWarning("Selected CPPs with the following EO IDs are being excluded because they were marked as not approved: "+ ','.join([str(x) for x in excluded_eoids]))
        else:
            pass

        # add reporting messages about which CPPs are being included and exit with message if no selected CPPs are current or approved.
        if len(eoids) != 0:
            arcpy.AddMessage("Selected CPPs with the following EO IDs are being used to create this NHA: "+','.join([str(x) for x in eoids]))
            arcpy.AddMessage("......")
        else:
            arcpy.AddWarning("Your CPP selection does not include any current or approved CPPs and we cannot proceed. Goodbye.")
            sys.exit()

        # create sql query based on number of CPPs included in query.
        if len(eoids) > 1:
            sql_query = '"EO_ID" in {}'.format(tuple(eoids))
        else:
            sql_query = '"EO_ID" = {}'.format(eoids[0])

        arcpy.AddMessage("Creating and attributing NHA core for site: "+ site_name)
        arcpy.AddMessage("......")
        # create cpp_core layer from selected CPPs marked as current or approved and dissolve to create temporary nha geometry
        cpp_core_lyr = arcpy.MakeFeatureLayer_management(cpp_core, "cpp_core_lyr", sql_query)
        temp_nha = os.path.join(mem_workspace,"temp_nha")
        temp_nha = arcpy.Dissolve_management(cpp_core_lyr, temp_nha)

        # get geometry token from nha
        with arcpy.da.SearchCursor(temp_nha,"SHAPE@") as cursor:
            for row in cursor:
                geom = row[0]

        # calculate NHA_JOIN_ID which includes network username and the next highest tiebreaker for that username padded to 6 places
        username = getuser().lower()
        where = '"NHA_JOIN_ID" LIKE'+"'%{0}%'".format(username)
        with arcpy.da.SearchCursor(nha_core, 'NHA_JOIN_ID', where_clause = where) as cursor:
            join_ids = sorted({row[0] for row in cursor})
        if len(join_ids) == 0:
            nha_join_id = username + '000001'
        else:
            t = join_ids[-1]
            tiebreak = str(int(t[-6:])+1).zfill(6)
            nha_join_id = username + tiebreak

        # test for unsaved edits - alert user to unsaved edits and end script
        try:
            # open editing session and insert new NHA Core record
            values = [site_name,"NHA","D",site_desc,"1306 - Conservation Planning",source_report,nha_join_id,geom]
            fields = ["SITE_NAME","SITE_TYPE","STATUS","BRIEF_DESC","PROJECT","SOURCE_REPORT","NHA_JOIN_ID","SHAPE@"]
            with arcpy.da.InsertCursor(nha_core,fields) as cursor:
                cursor.insertRow(values)
        except RuntimeError:
            arcpy.AddWarning("You have unsaved edits in your NHA layer. Please save or discard edits and try again.")
            sys.exit()

######################################################################################################################################################
## create NHA Supporting and get NHA Supporting attributes
######################################################################################################################################################

        arcpy.AddMessage("Creating and attributing NHA supporting for site: "+ site_name)
        arcpy.AddMessage("......")
        # create supporting cpp layer from selected CPPs marked as current or approved and dissolve to create temporary nha supporting geometry
        cpp_supporting_lyr = arcpy.MakeFeatureLayer_management(cpp_supporting, "cpp_supporting_lyr", sql_query)
        with arcpy.da.SearchCursor(cpp_supporting_lyr,"EO_ID") as cursor:
            cpp_supp = sorted({row[0] for row in cursor})
        if len(cpp_supp) == 0:
            arcpy.AddWarning("No supporting CPPs exist for the selected CPP cores in this area. No NHA Supporting landscape has been drawn. Please review the CPP supporting polygons in this area.")
        else:
            temp_nha_supp = arcpy.Dissolve_management(cpp_supporting_lyr, os.path.join(mem_workspace,"temp_nha_supp"))

            # get geometry for nha supporting
            with arcpy.da.SearchCursor(temp_nha_supp,"SHAPE@") as cursor:
                for row in cursor:
                    geom_supp = row[0]

            # test for unsaved edits - alert user to unsaved edits and end script
            try:
                # start editing session and insert new NHA Supporting record
                values = [nha_join_id,"D",geom_supp]
                fields = ["NHA_JOIN_ID","STATUS","SHAPE@"]
                with arcpy.da.InsertCursor(nha_supporting,fields) as cursor:
                    cursor.insertRow(values)
            except RuntimeError:
                arcpy.AddWarning("You have unsaved edits in your NHA layer. Please save or discard edits and try again.")
                sys.exit()
######################################################################################################################################################
## Insert species records into NHA species table
######################################################################################################################################################

        # make EO layer with selected EOs that were used to create the NHA layer
        eo_reps_lyr = arcpy.MakeFeatureLayer_management(eo_reps,"eo_reps_lyr",sql_query)
        SpeciesInsert = []
        # report which EOs were included in NHA and add EO records to list to be inserted into NHA species table
        arcpy.AddMessage("The following species records have been added to the NHA Species Table for NHA with site name, "+site_name+":")
        for eoid in eoids:
            with arcpy.da.SearchCursor(eo_reps, ["ELCODE","ELSUBID","SNAME","SCOMNAME","EO_ID"], '"EO_ID" = {}'.format(eoid)) as cursor:
                for row in cursor:
                    values = tuple([row[0],row[1],row[2],row[3],element_type(row[0]),row[4],nha_join_id])
                    arcpy.AddMessage(values)
                    SpeciesInsert.append(values)
        arcpy.AddMessage("......")

        # insert EO records into NHA species table
        for insert in SpeciesInsert:
            with arcpy.da.InsertCursor(spec_tbl, ["ELCODE","ELSUBID","SNAME","SCOMNAME","ELEMENT_TYPE","EO_ID","NHA_JOIN_ID"]) as cursor:
                cursor.insertRow(insert)

        # report about EOs that overlap the NHA core, but were not included in the NHA species table
        eo_reps_full = arcpy.MakeFeatureLayer_management(eo_reps,"eo_reps_full")
        arcpy.SelectLayerByLocation_management(eo_reps_full,"INTERSECT",temp_nha,selection_type="NEW_SELECTION")
        arcpy.AddWarning("The following EO rep records intersected your NHA, but do not have a CPP drawn:")
        with arcpy.da.SearchCursor(eo_reps_full,["EO_ID","SNAME","SCOMNAME","LASTOBS_YR","EORANK","EO_TRACK","EST_RA","PREC_BCD"]) as cursor:
            for row in cursor:
                if row[0] not in eoids:
                    arcpy.AddWarning(row)
                else:
                    pass

        arcpy.AddMessage("......")
        arcpy.AddMessage("The initial NHA core and supporting landscapes were created for site name, "+site_name+". Please make any necessary manual edits. Once spatial edits are complete, don't forget to run step 2. Fill NHA Spatial Attributes")

######################################################################################################################################################
## Begin fill nha spatial attributes tool which finishes attributes that depend on manual edits
######################################################################################################################################################

class FillAttributes(object):
    def __init__(self):
        """Define the tool (tool name is the name of the class)."""
        self.label = "2 Fill NHA Spatial Attributes - Version 3"
        self.description = ""
        self.canRunInBackground = False

    def getParameterInfo(self):
        nha_core = arcpy.Parameter(
            displayName = "Selected NHA Core Layer",
            name = "nha_core",
            datatype = "GPFeatureLayer",
            parameterType = "Required",
            direction = "Input")
        nha_core.value = r'NHAEdit\NHA Core Habitat'

        arcmap = arcpy.Parameter(
            displayName = "Check box if you are using ArcMap 10.xx instead of ArcGIS Pro.",
            name = "arcmap",
            datatype = "GPBoolean",
            parameterType = "optional",
            direction = "Input")

        params = [nha_core, arcmap]
        return params

    def isLicensed(self):
        return True

    def updateParameters(self, params):
        return

    def updateMessages(self, params):
        return

    def execute(self, params, messages):

        nha_core = params[0].valueAsText
        arcmap = params[1].valueAsText

        # set memory workspace
        if str(arcmap) == 'true':
            mem_workspace = "in_memory"
        else:
            mem_workspace = "memory"

        # define paths
        username = getuser().lower()
        muni = r'C:\\Users\\'+username+r'\\AppData\\Roaming\\Esri\\ArcGISPro\\Favorites\\StateLayers.Default.pgh-gis0.sde\\StateLayers.DBO.Boundaries_Political\\StateLayers.DBO.PaMunicipalities'
        prot_lands = r'C:\\Users\\'+username+r'\\AppData\\Roaming\\Esri\\ArcGISPro\\Favorites\\StateLayers.Default.pgh-gis0.sde\\StateLayers.DBO.Protected_Lands\\StateLayers.DBO.TNC_Secured_Areas'
        usgs_quad = r'W:\LYRS\Indexes\QUAD 24K.lyr'
        prot_lands_tbl = r'PNHP.DBO.NHA_ProtectedLands'
        boundaries_tbl = r'PNHP.DBO.NHA_PoliticalBoundaries'

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
        nha_current_lyr = arcpy.MakeFeatureLayer_management(nha_core, "nha_current_lyr", "STATUS in ('C','H')")

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

######################################################################################################################################################
## calculate acres, USGS quads, and old site names for NHA Core
######################################################################################################################################################


            # test for unsaved edits - alert user to unsaved edits and end script
            try:
                # get attributes for usgs quad and old site names
                usgs_quad_att = get_attribute(usgs_quad,nha_core_lyr,"NAME")
                old_site_name_att = get_attribute(nha_current_lyr,nha_core_lyr,"SITE_NAME")
                with arcpy.da.UpdateCursor(nha_core_lyr,["ACRES","SHAPE@","USGS_QUAD","OLD_SITE_NAME"]) as cursor:
                    for row in cursor:
                        acres = round(row[1].getArea("GEODESIC","ACRES"),3)
                        row[0] = acres
                        row[2] = usgs_quad_att
                        row[3] = old_site_name_att
                        arcpy.AddMessage(nha +" Acres: "+str(acres))
                        arcpy.AddMessage("......")
                        arcpy.AddMessage(nha + " USGS Quads: "+usgs_quad_att)
                        arcpy.AddMessage("......")
                        arcpy.AddMessage(nha + " old site names: "+old_site_name_att)
                        arcpy.AddMessage("......")
                        cursor.updateRow(row)
            except RuntimeError:
                arcpy.AddWarning("You have unsaved edits in your NHA layer. Please save or discard edits and try again.")
                sys.exit()

######################################################################################################################################################
## attribute boundaries table
######################################################################################################################################################

            # attribute the counties and municipalities based on those that intersect the nha
            arcpy.SelectLayerByLocation_management(muni_lyr,"INTERSECT",nha_core_lyr,selection_type="NEW_SELECTION")
            MuniInsert = []
            with arcpy.da.SearchCursor(muni_lyr,["CountyName","FullName"]) as cursor:
                for row in cursor:
                    values = tuple([row[0].title(),row[1],nha])
                    MuniInsert.append(values)
            arcpy.AddMessage(nha + " Boundaries: ")
            for insert in MuniInsert:
                with arcpy.da.InsertCursor(boundaries_tbl,["COUNTY","MUNICIPALITY","NHA_JOIN_ID"]) as cursor:
                    arcpy.AddMessage(insert)
                    cursor.insertRow(insert)
            arcpy.AddMessage("......")

######################################################################################################################################################
## attribute protected lands table
######################################################################################################################################################

            # tabulate intersection to get percent and name of protected land that overlaps nha
            tab_area = arcpy.TabulateIntersection_analysis(nha_core_lyr,arcpy.Describe(nha_core_lyr).OIDFieldName,prot_lands,os.path.join(mem_workspace,"tab_area"),"AREA_NAME")
            # insert name and percent overlap of protected lands
            ProtInsert = []
            with arcpy.da.SearchCursor(tab_area,["AREA_NAME","PERCENTAGE"]) as cursor:
                for row in cursor:
                    values = tuple([row[0].title(),round(row[1],2),nha])
                    ProtInsert.append(values)
            arcpy.AddMessage(nha+ " Protected Lands: ")
            if ProtInsert:
                for insert in ProtInsert:
                    with arcpy.da.InsertCursor(prot_lands_tbl,["PROTECTED_LANDS","PERCENT_","NHA_JOIN_ID"]) as cursor:
                        arcpy.AddMessage(insert)
                        cursor.insertRow(insert)
            else:
                arcpy.AddMessage("No protected lands overlap the NHA core.")
            arcpy.AddMessage("#########################################################")
            arcpy.AddMessage("#########################################################")

######################################################################################################################################################
######################################################################################################################################################

######################################################################################################################################################
## Begin Site Rank Fill Tool
######################################################################################################################################################

class SiteRankFill(object):
    def __init__(self):
        """Define the tool (tool name is the name of the class)."""
        self.label = "3 Site Rank Fill Tool - Version 1"
        self.description = ""
        self.canRunInBackground = False

    def getParameterInfo(self):
        nha_core = arcpy.Parameter(
            displayName = "Selected NHA Core Layer",
            name = "nha_core",
            datatype = "GPFeatureLayer",
            parameterType = "Required",
            direction = "Input")
        nha_core.value = r'NHAEdit\NHA Core Habitat'

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

        #sqlite database path
        db = r'P:\Conservation Programs\Natural Heritage Program\ConservationPlanning\NaturalHeritageAreas\_NHA\z_Databases\NaturalHeritageAreas.sqlite'
        #connect to sqlite db
        con = lite.connect(db)
        #open cursor in sqlite db
        with con:
            cur = con.cursor()
        #create dataframe from sqlite data
        query = 'SELECT NHA_JOIN_ID,site_score,date_run FROM nha_runrecord ORDER BY NHA_JOIN_ID ASC;'
        df = pd.read_sql(query,con)
        #drop duplicate site runs based on the most recent
        df = df.sort_values('date_run').drop_duplicates(subset='NHA_JOIN_ID',keep='last')
        #create and fill dictionary with nha_join_id and site_score
        dictionary = {}
        dictionary = df.set_index('NHA_JOIN_ID')['site_score'].to_dict()
        #use dictionary to fill sig_rank in NHA core layer
        with arcpy.da.UpdateCursor(nha_core,["NHA_JOIN_ID","SIG_RANK"]) as cursor:
            for row in cursor:
                for k,v in dictionary.items():
                    if k==row[0]:
                        if v == "Global":
                            row[1]="G"
                            cursor.updateRow(row)
                        elif v == "Regional":
                            row[1]="R"
                            cursor.updateRow(row)
                        elif v == "State":
                            row[1]="S"
                            cursor.updateRow(row)
                        elif v == "Local":
                            row[1]="L"
                            cursor.updateRow(row)
                        else:
                            pass
                    else:
                        pass

######################################################################################################################################################
######################################################################################################################################################

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
        nha_query.filter.list = ["Only Current NHAs","Only Completed - Not Published NHAs","All Current or Completed - Not Published NHAs"]
        nha_query.value = "All Current or Completed - Not Published NHAs"

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

##        #establish rest endpoint urls
##        eo_url = r'https://maps.waterlandlife.org/arcgis/rest/services/PNHP/Biotics/FeatureServer/0'
##        nha_core_url = r'https://maps.waterlandlife.org/arcgis/rest/services/PNHP/NHAEdit/FeatureServer/0'
##        nha_supporting_url = r'https://maps.waterlandlife.org/arcgis/rest/services/PNHP/NHAEdit/FeatureServer/1'
##        political_url = r'https://maps.waterlandlife.org/arcgis/rest/services/PNHP/NHAEdit/FeatureServer/2'
##        protected_url = r'https://maps.waterlandlife.org/arcgis/rest/services/PNHP/NHAEdit/FeatureServer/3'
##        species_url = r'https://maps.waterlandlife.org/arcgis/rest/services/PNHP/NHAEdit/FeatureServer/4'

        username = getuser().lower()
        eo_url = r'C:\\Users\\'+username+r'\\AppData\\Roaming\\Esri\\ArcGISPro\\Favorites\\PNHP.Default.pgh-gis0.sde\\PNHP.DBO.Biotics\\PNHP.DBO.eo_ptreps'
        nha_core_url = r'C:\\Users\\'+username+r'\\AppData\\Roaming\\Esri\\ArcGISPro\\Favorites\\PNHP.Default.pgh-gis0.sde\\PNHP.DBO.NHA_Core'
        nha_supporting_url = r'C:\\Users\\'+username+r'\\AppData\\Roaming\\Esri\\ArcGISPro\\Favorites\\PNHP.Default.pgh-gis0.sde\\PNHP.DBO.NHA_Supporting'
        political_url = r'C:\\Users\\'+username+r'\\AppData\\Roaming\\Esri\\ArcGISPro\\Favorites\\PNHP.Default.pgh-gis0.sde\\PNHP.DBO.NHA_PoliticalBoundaries'
        protected_url = r'C:\\Users\\'+username+r'\\AppData\\Roaming\\Esri\\ArcGISPro\\Favorites\\PNHP.Default.pgh-gis0.sde\\PNHP.DBO.NHA_ProtectedLands'
        species_url = r'C:\\Users\\'+username+r'\\AppData\\Roaming\\Esri\\ArcGISPro\\Favorites\\PNHP.Default.pgh-gis0.sde\\PNHP.DBO.NHA_SpeciesTable'

        #check for selection. error out if no selection is made.
        desc = arcpy.Describe(nha_core)
        if not desc.FIDSet == '':
            pass
        else:
            arcpy.AddWarning("No NHA Cores are selected. Please make a selection and try again.")
            sys.exit()

        #create empty database
        arcpy.AddMessage("Creating Database")
        gdb = arcpy.CreateFileGDB_management(os.path.dirname(output_gdb),os.path.basename(output_gdb)+".gdb")

        #create list of qualifying NHA_JOIN_IDs to be exported in selection based on selection of current or completed not published
        with arcpy.da.SearchCursor(nha_core,["NHA_JOIN_ID","STATUS"]) as cursor:
            if nha_query == "Only Current NHAs":
                nha_ids = sorted({row[0] for row in cursor if row[0] is not None and row[1] == 'C'})
            elif nha_query == "Only Completed - Not Published NHAs":
                nha_ids = sorted({row[0] for row in cursor if row[0] is not None and row[1] == 'NP'})
            else:
                nha_ids = sorted({row[0] for row in cursor if row[0] is not None and (row[1] == 'NP' or row[1] == 'C')})

        #construct where query for feature set load statements
        nha_expression = "NHA_JOIN_ID IN ({0})".format(','.join("'{0}'".format(id) for id in nha_ids))

        #load qualifying core NHAs to feature set and save in output file gdb
        arcpy.AddMessage("Copying Selected NHA Cores")

        #use fieldmap to remove unwanted fields
        fieldmappings = arcpy.FieldMappings()
        #Add all fields from inputs.
        fieldmappings.addTable(nha_core_url)
        # Name fields you want to delete.
        losers = ["ARCHIVE_DATE", "ARCHIVE_REASON", "created_date","created_user","last_edited_date","last_edited_user","MAP_ID","NOTES","OLD_SITE_NAME","STATUS","SOURCE_REPORT","PROJECT","BLUEPRINT"] # etc.
        #Remove all output fields you don't want.
        for field in fieldmappings.fields:
            if field.name in losers:
                fieldmappings.removeFieldMap(fieldmappings.findFieldMapIndex(field.name))

        arcpy.FeatureClassToFeatureClass_conversion(nha_core_url,output_gdb+".gdb","NHA_Core",nha_expression,fieldmappings)

        #load qualifying supporting NHAs to feature set and save in output file gdb
        arcpy.AddMessage("Copying NHA Supporting")
        #use fieldmap to remove unwanted fields
        fieldmappings = arcpy.FieldMappings()
        fieldmappings.addTable(nha_supporting_url)
        for field in fieldmappings.fields:
            if field.name in losers:
                fieldmappings.removeFieldMap(fieldmappings.findFieldMapIndex(field.name))

        arcpy.FeatureClassToFeatureClass_conversion(nha_supporting_url,output_gdb+".gdb","NHA_Supporting",nha_expression,fieldmappings)

##        nha_supporting_fs = arcpy.FeatureSet()
##        nha_supporting_fs.load(nha_supporting_url,nha_expression)
##        nha_supporting_fs.save(os.path.join(output_gdb+".gdb","NHA_Supporting"))
        #create relationship class between nha core and nha supporting feature classes
        arcpy.CreateRelationshipClass_management(os.path.join(output_gdb+".gdb","NHA_Core"),os.path.join(output_gdb+".gdb","NHA_Supporting"),os.path.join(output_gdb+".gdb","NHA_Core_TO_Supporting"),"SIMPLE","Core_TO_Supporting","Supporting_TO_Core","NONE","ONE_TO_MANY","NONE","NHA_JOIN_ID","NHA_JOIN_ID")

        #load qualifying political boundary records and save to output gdb
        arcpy.AddMessage("Copying Political Boundaries Table")
        arcpy.TableToTable_conversion(political_url,output_gdb+".gdb","PoliticalBoundaries",nha_expression)

##        political_fs = arcpy.RecordSet()
##        political_fs.load(political_url,nha_expression)
##        political_fs.save(os.path.join(output_gdb+".gdb","PoliticalBoundaries"))
        #create relationship class between nha core and political boundaries table
        arcpy.CreateRelationshipClass_management(os.path.join(output_gdb+".gdb","NHA_Core"),os.path.join(output_gdb+".gdb","PoliticalBoundaries"),os.path.join(output_gdb+".gdb","NHA_Core_TO_Political"),"SIMPLE","Core_TO_Political","Political_TO_Core","NONE","ONE_TO_MANY","NONE","NHA_JOIN_ID","NHA_JOIN_ID")

        #load qualifying protected lands records and save to output gdb
        arcpy.AddMessage("Copying Protected Lands Table")
        arcpy.TableToTable_conversion(protected_url,output_gdb+".gdb","ProtectedLands",nha_expression)

##        protected_fs = arcpy.RecordSet()
##        protected_fs.load(protected_url,nha_expression)
##        protected_fs.save(os.path.join(output_gdb+".gdb","ProtectedLands"))
        #create relationship class between nha core and protected lands table
        arcpy.CreateRelationshipClass_management(os.path.join(output_gdb+".gdb","NHA_Core"),os.path.join(output_gdb+".gdb","ProtectedLands"),os.path.join(output_gdb+".gdb","NHA_Core_TO_Protected"),"SIMPLE","Core_TO_Protected","Protected_TO_Core","NONE","ONE_TO_MANY","NONE","NHA_JOIN_ID","NHA_JOIN_ID")

        #check if species table should be copied
        if sensitive_species == "Exclude species table from export":
            arcpy.AddMessage("You have chosen not to include the species table in your export")
            pass
        else:
            #load qualifying species table records and save to output gdb
            arcpy.AddMessage("Copying Species Table")
            arcpy.TableToTable_conversion(species_url,output_gdb+".gdb","SpeciesTable",nha_expression)

##            species_fs = arcpy.RecordSet()
##            species_fs.load(species_url,nha_expression)
##            species_fs.save(os.path.join(output_gdb+".gdb","SpeciesTable"))
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
                with arcpy.da.UpdateCursor(os.path.join(output_gdb+".gdb","SpeciesTable"),["EO_ID","ELCODE","ELSUBID","SNAME","SCOMNAME","ELEMENT_TYPE"]) as cursor:
                    for row in cursor:
                        if row[0] in sensitive_eos:
                            row[0] = None
                            row[1] = None
                            row[2] = None
                            row[3] = "SENSITIVE SPECIES"
                            row[4] = "SENSITIVE SPECIES"
                            row[5] = None
                            cursor.updateRow(row)
                        else:
                            pass
            else:
                arcpy.AddMessage("You have chosen not to mask sensitive species")

##        arcpy.AddMessage("Creating and assigning domains")
##        #create significance rank domain and assign to sig rank field
##        arcpy.CreateDomain_management(output_gdb+".gdb","SIG_RANK_1","Significance rank","TEXT","CODED")
##        sig_rank_dict = {"G":"Global", "R":"Regional", "S":"State", "L":"Local"}
##        for code in sig_rank_dict:
##            arcpy.AddCodedValueToDomain_management(output_gdb+".gdb","SIG_RANK_1",code,sig_rank_dict[code])
##        arcpy.AssignDomainToField_management(os.path.join(output_gdb+".gdb","NHA_Core"),"SIG_RANK","SIG_RANK_1")
##
##        #create status domain and assign to status field
##        arcpy.CreateDomain_management(output_gdb+".gdb","NHA_STATUS","NHA completion status","TEXT","CODED")
##        status_dict = {"D":"Draft", "NR":"Completed - Needs Review", "NP":"Completed - Not Published", "C":"Current", "RN":"Revision Needed", "H":"Historic"}
##        for code in status_dict:
##            arcpy.AddCodedValueToDomain_management(output_gdb+".gdb","NHA_STATUS",code,status_dict[code])
##        arcpy.AssignDomainToField_management(os.path.join(output_gdb+".gdb","NHA_Core"),"STATUS","NHA_STATUS")
##
##        #create element type domain and assign to element type field
##        arcpy.CreateDomain_management(output_gdb+".gdb","ELEM_TYPE","Element type","TEXT","CODED")
##        elem_dict = {"AAAA":"Salamander", "AAAB":"Frog", "AB":"Bird", "AF":"Fish", "AM":"Mammal", "AR":"Reptile", "CGH":"Community", "I":"Invertebrate - Other", "ICMAL":"Invertebrate - Crayfishes", "IICOL":"Invertebrate - Other Beetles", "IICOL02":"Invertebrate - Tiger Beetles", "IIEPH":"Invertebrate - Mayflies", "IIHYM":"Invertebrate - Bees", "IILEP":"Invertebrate - Butterflies and Skippers", "IILEY":"Invertebrate - Moths", "IIODO":"Invertebrate - Dragonflies and Damselflies", "IIORT":"Invertebrate - Grasshoppers", "IIPLE": "Invertebrate - Stoneflies", "IITRI":"Invertebrate - Caddisflies", "ILARA":"Invertebrate - Spiders", "IMBIV":"Invertebrate - Mussels", "IMGAS":"Invertebrate - Gastropods", "IZSPN":"Invertebrate - Sponges", "N":"Nonvascular Plants", "O":"Other", "P":"Vascular Plants"}
##        for code in elem_dict:
##            arcpy.AddCodedValueToDomain_management(output_gdb+".gdb","ELEM_TYPE",code,elem_dict[code])
##        arcpy.AssignDomainToField_management(os.path.join(output_gdb+".gdb","SpeciesTable"),"ELEMENT_TYPE","ELEM_TYPE")