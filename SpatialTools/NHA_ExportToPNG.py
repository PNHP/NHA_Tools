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
aprx = r"W:\\Heritage\\temp\\NHA_ReportMaps\\NHA_ReportMaps.aprx"
output_folder = r"W:\\Heritage\\temp\\NHA_ReportMaps\\output_PNG"

# set projects, layouts, and establish map series
p = arcpy.mp.ArcGISProject(aprx)
l = p.listLayouts()[0]
if not l.mapSeries is None:
    ms = l.mapSeries
# export map series
if ms.enabled:
    for pageNum in range(1, ms.pageCount + 1):
        ms.currentPageNumber = pageNum
        print("Exporting {0}".format(ms.pageRow.SITE_NAME))
        pageName = ms.pageRow.SITE_NAME
        l.exportToPNG(os.path.join(output_folder,f"{ms.pageRow.SITE_NAME}.png"),resolution=200)