import arcpy
from pathlib import Path
import os

nha_url = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_Beta_No_Edit/FeatureServer/0"

current_directory = Path(__file__).parent
current_directory = r"H:\Scripts\NHA_Tools\SiteReports"

output_folder = os.path.join(current_directory,"_data", "photos")

arcpy.management.ExportAttachments(nha_url, output_folder, "", "REPLACE", "nha_join_id")