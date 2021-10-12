# import packages
from itertools import groupby
from operator import itemgetter

nha_core = arcpy.GetParameterAsText(0)

# groupby iterator used to keep records with highest proportion overlap
case_field = "COUNTY_NAM" # defining fields within which to create groups
sort_field = "SITE_NAME" # define field to sort within groups
sql_orderby = "ORDER BY {}, {} ASC".format(case_field, sort_field) # sql code to order by case fields and max field within unique groups

# begin update cursor
with arcpy.da.UpdateCursor(nha_core, ["COUNTY_NAM","SITE_NAME","MAP_ID"], sql_clause=(None, sql_orderby)) as cursor:
    for key, group in groupby(cursor,lambda x: x[0]): # create groupby iterators by county name
        i = 1 # start count at 1 for each group
        for row in group:
            row[2] = i
            i+=1
            cursor.updateRow(row)