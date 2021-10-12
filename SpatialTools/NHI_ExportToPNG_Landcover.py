#-------------------------------------------------------------------------------
# Name:        NHA_ExportToPNG
# Purpose:     Copy and paste to Pro to export NHAs to PNGs
#
# Author:      MMoore
# Created:     10/14/2020
#
# Updates:     Future updates include incorporating this into the script tool.
#-------------------------------------------------------------------------------

# import packages
import arcpy, os, sys

# set paths to aprx and output folder
aprx = r"E:\\NHA_CountyIntroMaps\\NHA_CountyIntroMaps_Landcover.aprx"
output_folder = r"P:\\Conservation Programs\\Natural Heritage Program\\ConservationPlanning\\NaturalHeritageAreas\\_NHA\\z_BaseImages\\introMaps"

# set projects, layouts, and establish map series
p = arcpy.mp.ArcGISProject(aprx)
l = p.listLayouts()[0]
if not l.mapSeries is None:
    ms = l.mapSeries
# export map series
if ms.enabled:
    for pageNum in range(1, ms.pageCount + 1):
        ms.currentPageNumber = pageNum
        print("Exporting {0}".format(ms.pageRow.COUNTY_NAM))
        pageName = ms.pageRow.COUNTY_NAM
        l.exportToPNG(os.path.join(output_folder,"Layout_Landcover_" + ''.join(e for e in (ms.pageRow.COUNTY_NAM) if e.isalnum()) + ".png"),resolution=200)
