'''
Name:        NHA Tools
Purpose:

Author:      K. Erath

Created:     15Jan2014
Updated:     11Dec2017

Updates:
6/8/2017
NHA Version 2 Tool
- allow the path of the Supporting Landscapes to be set via a parameter. 
- tried to delete the v1 tool - no long relevant
7/24/2014
NHA Version 1 Tool
- Truncate old site name if it is longer than the limit for that field (70 characters)
5/28/2014
NHA Version 2 Tool
- Use insert cursor instead of append. This method gives more informative error messages when a value is too long for a text field.
- Use editor object so that multiple insert/update cursors can be used
- Test to make sure user is editing the correct workspace at beginning of script
- Remove from parameters NHA Core, NHA Supporting, Species table. They are now accessed directly from user's version of PNHP geodatabase.
5/15/2014
-Updated for new Biotics 5 data
4/22/2014
-Changed way to get OLD_SITE_NAME. Getting the data source of the layer was not
working. Now using the input feature layer instead of the data source (full pathname to feature class).
4/16/2014
-OLD_SITE_NAME field now populated with names of "current" NHAs that intersect the new NHA
-Updated element type function to include 'Invertebrate-Other'
3/12/2014
-Updated elcode type function to include amphibians
3/11/2014
-Changed municipality attribute to include county names
-Made EO ID query a message instead of a warning in the dialog box
-Commented out number of 'records in cpp layer to be dissolved and appended to nha core warning to dialog box
2/5/2014
-Added Source Report to input parameters
-Added try, except, and finally blocks so script always clears in memory workspace at end
-Added test to see if script enters update cursor for NHA Core
-Exclude CPPs marked 'n' or 'p' & add warning to dialog box that those CPPs were not included
2/4/2014
-Added if exists line to first line of get_attribute function
1/23/2014
-Creates supporting NHA in addition to core
-Lists all counties, not just one
-No reprojections within script -> did away with nha_temp file going to scratch geodatabase
-Calculates municipalities, usgs quads, and protected lands
3/2/2016
- upgraded all the lines that reference the ArcGIS version to 10.3 from 10.2
- Add new users to user dictionary - 'pwoods', 'sschuette', 'bgeorgic'
3/3/2016
- Must establish a direct Database Connection to user version of database in ArcCatalog through Geodatabase Connection Properties; use syntax 'PNHP.username.phg-gis'
11/29/2017
-Updated connections to pgh-gis0. Updated changed file names for input sources: Quad24k, PaMunicipalities
12/11/2017
-Updated PaMunicipalities field to 'MUNICIPAL1', replacing 'Name_Proper_Type'in search cursor and added code for title case formatting. Request submitted to Brad Georgic to update values to include muni type. 

To Do List/Future Ideas:
*Batch tool that will work on counties/multiple counties
*Fill in donut holes? Maybe just for single NHA tool, not batch
*Some multipart CPPs should be different NHAs
'''

# import modules
import arcpy, time, datetime, sys, traceback
from getpass import getuser

# Set tools to overwrite existing outputs
arcpy.env.overwriteOutput = True

################################################################################
# Define global variables  and functions to be used throughout toolbox
################################################################################

# Dictionary of usernames and initials to use when determining NHA join ID
user_dict = {'kerath':'kje', 'ctracey':'ct', 'sschuette':'ss', 'pwoods':'pw', 'dyeany':'dly', 'bgeorgic':'bjg', 'ajohnson':'alj', 'mmoore':'mem'}

# List of exceptions to be used when extracting quad name, these will remain uppercase instead of being converted to title case
exceptions = ['NE', 'NW', 'SE', 'SW', 'US']

# Function to convert attributes from counties, municipalities, usgs quads, and protected lands to title case
def title_except(s, exceptions):
    '''Takes a string and a list of exceptions as input. Returns the string in
    title case, except any words in the exeptions list are not altered.
    string + Python list = string
    ROANOKE SW -> Roanoke SW
    '''
    # Turn string into a list of words
    word_list = s.split()
    # Final is an empty list that words will be appended to
    final = []
    # For each word in the list, append to the final list
    for word in word_list:
        # If the word is in exceptions, append the word. If not, append the word capitalized.
        final.append(word in exceptions and word or word.capitalize())
    # Return the list of final words converted to a string
    return " ".join(final)

# Function to get attributes from counties, municipalities, usgs quads, and protected lands
def get_attribute(in_fc, select_fc, field):
    '''Takes an input feature class that intersects the select_fc and returns
    attributes in the specified field. Attributes are returned as a string, that
    can then be added to another feature class attribute table.
    '''
    # Check to see if feature layer exists, if it does delete it (line written in response to ERROR 000725: Output Layer: Dataset in_fc_lyr already exists)
    if arcpy.Exists("in_fc_lyr"):
        arcpy.Delete_management("in_fc_lyr")
    # Make feature layer so selections can run
    arcpy.MakeFeatureLayer_management(in_fc, "in_fc_lyr")
    # Select features in in_fc that intersect select_fc
    arcpy.SelectLayerByLocation_management("in_fc_lyr", "INTERSECT", select_fc)
    # Use search cursor to retrieve attributes from field
    # Set the variable to contain attributes to an empty string
    attributes = ""
    # Use search cursor to access attributes in the input feature class
    srows = arcpy.da.SearchCursor("in_fc_lyr", [field])
    for srow in srows:
        # Name is the attribute converted to title case
        name = title_except(str(srow[0]), exceptions)
        # If the string is empty, make the string equal to name
        if attributes == "":
            attributes = name
        # If the string does not already contain name, add it to the string
        elif name not in attributes:
            attributes = "{0}, {1}".format(attributes, name)
        else:
            pass
    return attributes

# Function to shorten code when entering parameters
def parameter(displayName, name, datatype='GPFeatureLayer', defaultValue=None, parameterType='Required', direction='Input', multiValue=False):
    '''This function defines the parameter definitions for a tool. Using this
    function saves lines of code by prepopulating some of the values and also
    allows setting a default value.
    '''
    # create parameter with a few default properties
    param = arcpy.Parameter(
        displayName = displayName,
        name = name,
        datatype = datatype,
        parameterType = parameterType,
        direction = direction,
        multiValue = multiValue)

    # set new parameter to a default value
    param.value = defaultValue

    # return complete parameter object
    return param

# Function to to populate NHA Element Type using ELCODE from eoptreps
def element_type(elcode):
    '''Takes ELCODE as input and returns NHA element type code.
    '''
    if elcode.startswith('AB'):
        et = 'B' # Bird
    elif elcode.startswith('AM'):
        et = 'M' # Mammal
    elif elcode.startswith('IMBIV'):
        et = 'U' # Mussel
    elif elcode.startswith('P'):
        et = 'P' # Plant
    elif elcode.startswith('AR'):
        et = 'R' # Reptile
    elif elcode.startswith('AA'):
        et = 'A' # Amphibian
    elif elcode.startswith('C') or elcode.startswith('H'):
        et = 'C' # Community
    elif elcode.startswith('AF'):
        et = 'F' # Fish
    elif elcode.startswith('IILEP'):
        et = 'IB' # Invertebrate-Butterfly
    elif elcode.startswith('IILE'):
        et = 'IM' # Invertebrate-Moth
    elif elcode.startswith('IICOL02'):
        et = 'IT' # Invertebrate-Tiger Beetle
    elif elcode[:7] in ('IIODO65', 'IIODO66', 'IIODO67', 'IIODO68') or elcode.startswith('IIODO7'):
        et = 'IA' # Invertebrate-Damselfly
    elif elcode[:7] in ('IIODO61', 'IIODO64') or elcode[:6] in ('IIODO0', 'IIODO1', 'IIODO2', 'IIODO3', 'IIODO4', 'IIODO5', 'IIODO8'):
        et = 'ID' # Invertebrate-Dragonfly
    elif elcode.startswith('I'):
        et = 'IO' # Invertebrate-Other
    else:
        arcpy.AddWarning("Could not determine element type")
        et = None
    return et

def select_adjacent_features(initial_selection, search_distance = None):
    '''This function selects additional features within the input feature layer
    that are adjacent to the already selected features. If a search distance is
    specified, features within a distance of the selected features will be
    selected. If no search distance is specified, only contiguous features will
    be selected.
    '''
    # Get count of selected features in the initial selection
    count1 = (int(arcpy.GetCount_management(initial_selection).getOutput(0)))
    arcpy.AddMessage("Initial selection contains " + str(count1) + " features.")

    # If there is an initial selection, procede with script
    if count1 != 0:

        # Select additional features adjacent to the selected features
        arcpy.SelectLayerByLocation_management(initial_selection, "WITHIN_A_DISTANCE", "", search_distance, "ADD_TO_SELECTION")
        # Count number of selected features
        count2 = (int(arcpy.GetCount_management(initial_selection).getOutput(0)))

        # Count number of times an additional selection occurs
        selectionCount = 1

        # As long as the first count is less than the second count, continue selecting additional features
        while count1 < count2:
            # The second count becomes the first count
            count1 = count2
            # Select additional features adjacent to the selected features
            arcpy.SelectLayerByLocation_management(initial_selection, "WITHIN_A_DISTANCE", "", search_distance, "ADD_TO_SELECTION")
            # Count number of selected features
            count2 = (int(arcpy.GetCount_management(initial_selection).getOutput(0)))
            # Update count of times an additional selection occurs
            selectionCount += 1
##            arcpy.AddMessage("Selection loop number {0} has returned {1} records.".format(selectionCount, count2))
        arcpy.AddMessage("Selection complete. There are {} adjacent features.".format(count2))

    # If there is no initial selection, add error message
    else:
        arcpy.AddError("Input layer {} has no features or there is no initial selection.".format(initial_selection))

# Function to check if workspace is in an edit session
def check_edit_session(workspace):
    '''Checks to see if the workspace is being edited within ArcMap.

    If an edit session is in progress in ArcMap and the editor class is instantiated
    within the tool, trying to save edits at the end of the script will cause a
    RuntimeError. The try and except block uses that error to test to see if an edit
    session is in progress.

    Note that the editor class has a property (isEditing) to check if an edit session
    is in progress, but this only works on the editor object. It does not test to see
    if there is an edit session that was started within ArcMap. To read more about the
    editor class, google arcpy.da.editor.
    '''
    # Create an instance of the editor class
    edit = arcpy.da.Editor(workspace)
    # Start an editing session
    edit.startEditing()
    # Start an edit operation
    edit.startOperation()
    # Stop the edit operation
    edit.stopOperation()
    # Try to stop the edit session without saving changes
    try:
        # If it works, return false, no edit session
        edit.stopEditing(False)
        return False
    except RuntimeError:
        # If you get a runtime error, return True, the workspace is in an edit session
        return True

################################################################################
# Begin toolbox
################################################################################

class Toolbox(object):
    def __init__(self):
        """Define the toolbox (the name of the toolbox is the name of the
        .pyt file)."""
        self.label = "NHA Creator"
        self.alias = "NHA Creator"

        # List of tool classes associated with this toolbox
        self.tools = [CreateNHAv2]

# Define tool classes
class CreateNHAv2(object):
    def __init__(self):
        """Define the tool (tool name is the name of the class)."""
        self.label = "Create NHA - Version 2"
        self.description = ""
        self.canRunInBackground = False

    def getParameterInfo(self):
        """Define parameter definitions using parameter function, defined at top of toolbox."""
        # parameter(displayName, name, datatype='GPFeatureLayer', defaultValue=None, parameterType='Required', direction='Input', multiValue=False)
        params = [
        parameter('Site Name', 'site_name', 'GPString'),
        parameter('Source Report', 'src_report', 'GPString', defaultValue='None', parameterType='Optional'),
        parameter('Selected CPP Core(s)', 'cpp_core', defaultValue=r'Conservation Planning Polygons\CPP_Core'),
        parameter('CPP Supporting(s)', 'cpp_slp', defaultValue=r'Conservation Planning Polygons\CPP_Supporting'),
        parameter("Exclude CPPs marked 'not approved' or 'problematic source feature'", 'exclude_cpps', datatype='GPBoolean', defaultValue=True)]
        return params

    def execute(self, parameters, messages):
        """The source code of the tool."""
        # Define tool variables
        site_name = parameters[0].valueAsText
        src_report = parameters[1].valueAsText
        cpp_core = parameters[2].valueAsText
        cpp_slp = parameters[3].valueAsText  
        exclude_cpps = parameters[4].value
        # Example workspace: C:\Users\kerath\AppData\Roaming\ESRI\Desktop10.5\ArcCatalog\PNHP.kerath.pgh-gis.sde
        workspace = r"C:\Users\{0}\AppData\Roaming\ESRI\Desktop10.5\ArcCatalog\PNHP.{0}.pgh-gis0.sde".format(getuser())
        nha_core = r"{}\PNHP.DBO.NHA\PNHP.DBO.NHA_Core".format(workspace)
        nha_slp = r"{}\PNHP.DBO.NHA\PNHP.DBO.NHA_Supporting".format(workspace)
        spec_tbl = r"{}\PNHP.DBO.NHA_SpeciesTable".format(workspace)
        eoptreps = r"W:\Heritage\Heritage_Data\Biotics_datasets.gdb\eo_ptreps"
        
        pa_county = r"Database Connections\StateLayers.Default.pgh-gis0.sde\StateLayers.DBO.Boundaries_Political\StateLayers.DBO.County"
        muni = r"Database Connections\StateLayers.Default.PGH-GIS0.sde\StateLayers.DBO.Boundaries_Political\StateLayers.DBO.PaMunicipalities"
        quad = r"Database Connections\StateLayers.Default.PGH-GIS0.sde\StateLayers.DBO.Index\StateLayers.DBO.QUAD24K"
        prot_land = r"Database Connections\StateLayers.Default.pgh-gis0.sde\StateLayers.DBO.Protected_Lands\StateLayers.DBO.TNC_Secured_Areas"
        community_query = "SNAME in ('Pitch pine - heath woodland','Pitch pine - mixed hardwood woodland','Pitch pine - rhodora - scrub oak woodland','Pitch pine - scrub oak woodland','Red-cedar - pine serpentine shrubland','Rhodora - mixed heath - scrub oak shrubland','Low heath shrubland','Scrub oak shrubland','Little bluestem - pennsylvania sedge opening','Serpentine grassland','Calcareous opening/cliff','Side-oats gramma calcareous grassland','Serpentine gravel forb community','Great Lakes Region dry sandplain','Great Lakes Region sparsely vegetated beach')"

        # Define the workspace environment
        arcpy.env.workspace = "in_memory"
        # Set tools to overwrite existing outputs
        arcpy.env.overwriteOutput = True

        # Check to make sure the user is editing thier version of the geodatabase
        # For the NHA tool, you want the user to be editing thier version of the PNHP geodatabase, before running the tool
        if check_edit_session(workspace):
            pass
        else:
            arcpy.AddError("Start edit session for your version of the PNHP geodatabase")
            sys.exit()

        # Create an instance of the editor class so the update/insert cursors will run
        # Even if there is an edit session open within ArcMap, multiple insert and update cursors will not run within a script unless the editor class is instantiated
        edit = arcpy.da.Editor(workspace)
        # Start an editing session
        edit.startEditing()
        # Start an editing operation
        edit.startOperation()

        # Count number of selected records and print to dialog box
        count = arcpy.GetCount_management(cpp_core).getOutput(0)
        arcpy.AddWarning("\nTool is operating on {0} selected CPP Core(s) in layer '{1}'".format(count, cpp_core))
        arcpy.AddMessage("PNHP workspace: {}\n".format(workspace))

        ########################################################################
        arcpy.AddMessage("Merging CPP Core(s) at {0}".format(datetime.datetime.now().strftime("%H:%M:%S")))
        ########################################################################
        # List to store appended EO IDs
        eoids = []
        # List to store excluded EO IDs
        excluded_eoids = []
        # Use search cursor to get EO ID and status from CPP Cores
        srows = arcpy.da.SearchCursor(cpp_core, ["EO_ID", "Status", "ReviewNotes"])
        for srow in srows:
            # Get EO ID and Status attributes
            eoid = int(srow[0])
            status = str(srow[1])
            # If status is 'not approved' or 'problematic source feature' and exluded CPPs is checked, exclude CPP from the NHA
            if status in ['n', 'p'] and exclude_cpps == True:
                arcpy.AddWarning("EO ID {0} excluded. Status = {1}. Review Notes: {2}".format(eoid, status, srow[2]))
                # Append EO ID to excluded EO IDs
                excluded_eoids.append(eoid)
            # If exclude_cpps is NOT checked and CPP is marked 'n' or 'p', include the CPP in the NHA, but add a warning to the dialog box
            elif status in ['n', 'p'] and exclude_cpps == False:
                arcpy.AddWarning("EO ID {0} included. Status = {1}. Review Notes: {2}".format(eoid, status, srow[2]))
                # Append EO ID to included EO IDs
                eoids.append(eoid)
            # If CPP status is not 'n' or 'p', include the CPP
            else:
                eoids.append(eoid)

        # Create EO ID query to use in make feature layer operations
        if len(eoids) > 1:
            # If there is more than one EO ID use tuple format
            eoid_query = '"EO_ID" in {}'.format(tuple(eoids))
        else:
            # If there is only 1 EO ID use equal sign
            eoid_query = '"EO_ID" = {}'.format(eoids[0])

        arcpy.AddMessage("EO ID Query: {}".format(eoid_query))

        # Make feature layer of CPP core that excludes CPPs marked 'n' or 'p'
        arcpy.MakeFeatureLayer_management(cpp_core, "cpp_core_lyr", eoid_query)

        # Dissolve CPP(s) to one record (this also gets rid of attributes so status and project are not copied to nha)
        arcpy.Dissolve_management("cpp_core_lyr", "temp_nha")

        ########################################################################
        arcpy.AddMessage("\nCalculating attributes for NHA Core at {0}".format(datetime.datetime.now().strftime("%H:%M:%S")))
        ########################################################################
        # Get geometry of new nha core
        srows = arcpy.da.SearchCursor("temp_nha", "SHAPE@")
        for srow in srows:
            geom = srow[0]

        # Use get_attribute function defined at top of script to get attributes from counties, USGS quads, and protected lands
        counties = get_attribute(pa_county, "temp_nha", "COUNTY_NAM")
        arcpy.AddMessage("County name(s): {}".format(counties))
        quads = get_attribute(quad, "temp_nha", "NAME")
        arcpy.AddMessage("USGS Quad(s): {}".format(quads))
        prot_lands = get_attribute(prot_land, "temp_nha", "AREA_NAME")
        arcpy.AddMessage("Protected Land(s): {}".format(prot_lands))

        # Get municipalities and format attribute to display with corresponding county
        #---- Make municipality feature layer
        arcpy.MakeFeatureLayer_management(muni, "muni_lyr")
        #---- Select municipalities that intersect the NHA
        arcpy.SelectLayerByLocation_management("muni_lyr", "INTERSECT", "temp_nha")
        #---- Use search cursor to retrieve attributes, order by municipality name so that later the municipality lists will be populated in alphabetical order
        cursor = arcpy.da.SearchCursor("muni_lyr", ["CountyName", "MUNICIPAL1"], sql_clause=(None, "ORDER BY CountyName, MUNICIPAL1"))
        #---- Empty dictionary to store municipalities with corresponding county
        county_muni_dict = {}
        #---- Loop throough selected records in municipality feature layer
        for row in cursor:
            #---- Convert county to title case, and both unicode values to strings
            county = str(row[0]).title()
            municipality = str(row[1]).title()
            #---- If the county has not yet been added to the dictionary, add the county and the municipality
            if county not in county_muni_dict:
                county_muni_dict[county] = [municipality]
            #---- If the county is already in the dictionary, just append the municipality to the list of values for that county
            else:
                county_muni_dict[county].append(municipality)
        # The county-municipality dictionary now stores a list of muncipalities for each county
        # The county is the 'key' and the list of municipalities is the 'value'
        #---- Empty string to store MUNI attribute
        muni_attr = ""
        #---- Access the key and the value for each item in the sorted dictionary
        for key,val in sorted(county_muni_dict.items()):
            #---- Add county to the string
            muni_attr = "{0}{1} County:".format(muni_attr, key)
            #---- Loop through each municipality in the value (list of municipalities) and add it to the string
            for i in val:
                muni_attr = "{0} {1},".format(muni_attr, i)
            #---- Remove the comma that was added with the last municipality and replace it with a semicolon before going on to the next key (county)
            muni_attr = "{0}{1}".format(muni_attr.rstrip(","), "; ")
        #---- Remove the semicolon that was added with the completion of the last county
        muni_attr = muni_attr.rstrip("; ")
        arcpy.AddMessage("Municipalities(s): {}".format(muni_attr))

        # Get names of any overlapping NHAs to add to the OLD_SITE_NAME attribute
        #---- Make feature layer of nha cores that only include "current" and "not approved" polygons
        arcpy.MakeFeatureLayer_management(nha_core, "nha_current_lyr", "STATUS in ('NA','C')")
        #---- Get site name attributes from nha cores that intersect the new nha core
        old_sites = get_attribute("nha_current_lyr", "temp_nha", "SITE_NAME")
        arcpy.AddMessage("Old Site(s): {}".format(old_sites))

        # Get nha join id
        #---- Use Python getuser function to look up intitals in the username dictionary
        try:
            initials = user_dict[getuser()]
        except KeyError:
            arcpy.AddError("Username '{}' not recognized".format(getuser()))
            arcpy.AddWarning('''Add the above username to the tool:
\t*Right click NHA toolbox > Edit
\t*Search for 'user_dict'
\t*Edit current username and initials
\tOR
\t*Add username and initials to the Python dictionary
            ''')
            sys.exit()
        #---- Get most recent object id from nha core
        SQLpostfix = (None, 'ORDER BY OBJECTID DESC')
        cursor = arcpy.da.SearchCursor(nha_core, "OBJECTID", sql_clause = SQLpostfix)
        for row in cursor:
            object_id = row[0]
            break
        del cursor
        #---- The new nha id will be initials and the last object id plus 1
        nha_id = "{0}{1}".format(initials, object_id+1)
        arcpy.AddWarning("NHA Join ID: {}".format(nha_id))

        ########################################################################
        arcpy.AddMessage("\nUpdating NHA Core layer at {0}".format(datetime.datetime.now().strftime("%H:%M:%S")))
        ########################################################################
        # Insert values into new row in nha core layer
        values = [site_name,"D",counties,"Y", nha_id,'NHA','NHA site description is incomplete.','None',prot_lands,src_report,'1306 - Conservation Planning','DESCRIPTION NEEDED','THREATS NEEDED','RECOMMENDATIONS NEEDED','REFERENCES NEEDED','Not Applicable','Not Applicable',muni_attr,quads,old_sites, geom]
        fields = ["SITE_NAME", "STATUS", "COUNTY", "SUPPORTING", "NHA_JOIN_ID", "SITE_TYPE", "BRIEF_DESC", "ASSOC_NHA", "PROTECTED_LANDS", "REPORT_SOURCE", "PROJECT", "DESCRIPTION", "THREATS", "RECOMMENDATIONS", "REFERENCES_", "OLD_SIG_RANK", "ARCHIVE_REASON", "Muni", "USGS_QUAD", "OLD_SITE_NAME", "SHAPE@"]
        cursor = arcpy.da.InsertCursor(nha_core, fields)
##        objec_id = cursor.insertRow(values)
        cursor.insertRow(values)
        del cursor
##        # Update the nha join id based on the object id
##        urows = arcpy.da.UpdateCursor(nha_core, ["NHA_JOIN_ID", "OID@"])
##        for urow in urows:
##            if urow[1] == objec_id:
##                urow[0]="{0}{1}".format(urow[0],objec_id)
##                urows.updateRow(urow)

        ########################################################################
        arcpy.AddMessage("\nAdding new record(s) to species table at {0}".format(datetime.datetime.now().strftime("%H:%M:%S")))
        ########################################################################
        # Add new record to the species table for each EO ID in the EO ID list
        for eoid in eoids:
            # Use search cursor to get attributes from eo ptreps
            srows = arcpy.da.SearchCursor(eoptreps, ["SNAME", "SCOMNAME", "ELCODE", "GRANK", "SRANK", "SPROT", "PBSSTATUS", "LASTOBS", "EORANK", "SENSITV_SP"], '"EO_ID" = {}'.format(eoid))

            for srow in srows:
                # Write message to dialog box with species information
                arcpy.AddMessage("EO ID: {0}\nSpecies: {1}".format(eoid, srow[0]))
                # Determine element type
                el_type = element_type(srow[2])
                arcpy.AddMessage("Element Type: {0}".format(el_type))
                # Add attributes in search cursor to value list for insert cursor
                value_list = []
                # For a number n in the range 0-9
                for n in range(0,10):
                    value_list.append(srow[n])
                # Append NHA Join ID, EO ID, and Element Type to value list
                value_list.append(nha_id)
                value_list.append(eoid)
                value_list.append(el_type)

            # Use insert cursor to add new record to species table
            cursor = arcpy.da.InsertCursor(spec_tbl, ["SNAME", "SCOMNAME", "ELCODE", "G_RANK", "S_RANK", "S_PROTECTI", "PBSSTATUS", "LAST_OBS_D", "BASIC_EO_R", "SENSITIVE_", "NHA_JOIN_ID", "EO_ID", "ELEMENT_TYPE"])
            cursor.insertRow(value_list)
            # Delete cursor object
            del cursor

        ########################################################################
        arcpy.AddMessage("\nUpdating NHA Supporting at {0}".format(datetime.datetime.now().strftime("%H:%M:%S")))
        ########################################################################
        # Make feature layer of cpp supportings to be included in the nha
        arcpy.MakeFeatureLayer_management(cpp_slp, "cpp_slp_lyr", eoid_query)
        # Dissolve CPP(s) to one record (this also gets rid of attributes so status and project are not copied to nha)
        arcpy.Dissolve_management("cpp_slp_lyr", "temp_nha_slp")

        # Get geometry of new slp
        srows = arcpy.da.SearchCursor("temp_nha_slp", "SHAPE@")
        for srow in srows:
            geom = srow[0]

        # Use NHA Core to update attributes in NHA Supporting
        # Fields that are the same in NHA Core and Supporitng
        fields = ["SITE_NAME", "SITE_TYPE", "MAP_ID", "STATUS", "SIG_RANK", "BRIEF_DESC", "COUNTY", "MUNI", "USGS_QUAD", "ASSOC_NHA", "PROTECTED_LANDS", "REPORT_SOURCE", "PROJECT", "DESCRIPTION", "THREATS", "RECOMMENDATIONS", "REFERENCES_", "OLD_SITE_NAME", "OLD_SIG_RANK", "ARCHIVE_REASON", "ARCHIVE_DATE", "BLUEPRINT", "NOTES", "NHA_JOIN_ID", "Author", "AuthorDate"]
        # Get attributes from nha core where NHA Join ID = nha_id
        nha_query = "[{0}] = '{1}'".format("NHA_JOIN_ID", nha_id) # Use bracket format because nha is in SQL Server database
        srows = arcpy.da.SearchCursor(nha_core, fields, nha_query)
        for srow in srows:
            slp_values = list(srow)
        # Add geometry to the list of field names and list of attributes
        fields.append("SHAPE@")
        slp_values.append(geom)
        # Insert new row
        cursor = arcpy.da.InsertCursor(nha_slp, fields)
        cursor.insertRow(slp_values)
        del cursor

        # Stop the edit operation.
        edit.stopOperation()
        # Stop the edit session and try to save the changes
        # This should go straight to the exception since we checked to see if the user was editing the correct version of the geodatabase at the beginning of the tool
        try:
            edit.stopEditing(True)
            arcpy.AddWarning("\nArcMap was not in an edit session. Tool edits were saved.")
        # If the user was already in an edit session, a Runtime error willl be thrown
        except RuntimeError:
            # That is how the tool is normally run, so catch the exception and print a warning to remind the user to save edits
            arcpy.AddMessage("\nTool complete. Use Editor Toolbar to save edits.")
        return




################################################################################
# End toolbox. The class below is a template which can be used for creating new tools.
################################################################################

class Tool(object):
    def __init__(self):
        """Define the tool (tool name is the name of the class)."""
        self.label = "Tool"
        self.description = ""
        self.canRunInBackground = False

    def getParameterInfo(self):
        """Define parameter definitions using parameter function, defined at top of toolbox."""
        # parameter(displayName, name, datatype='GPFeatureLayer', defaultValue=None, parameterType='Required', direction='Input', multiValue=False)
        params = [
        parameter('Input Features', 'in_features'),
        parameter('Sinuosity Field', 'sinuosity_field', 'Field', 'sinuosity', 'Optional'),
        parameter('Output Features', 'out_features', parameterType='Derived', direction='Output')]

        return params

    def execute(self, parameters, messages):
        """The source code of the tool."""
        # Define tool variables
        in_features = parameters[0].valueAsText
        sinuosity_field = parameters[1].valueAsText
        out_features = parameters[2].valueAsText

        # Clear the in_memory workspace
        arcpy.Delete_management("in_memory")

        return
