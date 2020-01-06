mxd = arcpy.mapping.MapDocument("CURRENT")
ddp = mxd.dataDrivenPages
for pageNum in range(1, mxd.dataDrivenPages.pageCount + 1):
  mxd.dataDrivenPages.currentPageID = pageNum
  arcpy.mapping.ExportToPNG(mxd, r"C:\Users\dyeany\Documents\ArcGIS\CNHI\NHA_" + str(ddp.pageRow.SITE_NAME) + ".png", resolution=300)
del mxd


