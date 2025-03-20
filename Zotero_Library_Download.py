"""
---------------------------------------------------------------------------------------------------------------------
Name: Zotero_Library_Download.py
Purpose: This script downloads the PNHP Zotero library and updates the reference feature service that populates
the pick lists for the NHA Update Form. This script will run nightly to update the Zotero reference feature service.
Author: Molly Moore for Pennsylvania Natural Heritage Program
Created: 11/7/2024
Updates:
------------------------------------------------------------------------------------------------------------------------
"""

# import packages
import os
import json
import pandas as pd
import requests
import arcpy
from arcgis.gis import GIS
from arcgis.features import FeatureLayer
from pyzotero import zotero
import time

# define rest endpoint for zotero refs feature service which is used to populate the pick list in the NHA update form
zotero_ref_url = r"https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/5"
nha_reference_url = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/4"

# define the PNHP zotero library settings - you can find the library ID in the https address bar when you click on the library
library_id = 2166223
library_type = "group"
# we don't need the api key unless using the get_citation function - this can be found at zotero.org/settings/security#applications
api_key = "UrWywmlLjxitrqacPo5iV0Pf"

# define the api call address
api_url = r"https://api.zotero.org/groups/2166223/items?limit=100"

# this function fetches 100 results from the API at a time and then automatically starts next fetch if it exists until
# all records are fetched
def paginate_api(url):
    """Fetches data from a paginated API using 'rel=next' links."""
    results = []
    while url:
        print(url)
        try:
            response = requests.get(url)
            response.raise_for_status()
        except requests.exceptions.RequestException as ex:
            print(ex)

        data = response.json()
        results.extend(data)

        # Check for 'rel=next' link in the response headers
        link_header = response.headers.get('Link')
        if link_header:
            for link in link_header.split(','):
                if 'rel="next"' in link:
                    url = link.split(';')[0].strip(' <>')
                    break
            else:
                url = None
        else:
            url = None

    return results


# this function flattens a dictionary of dictionaries - in this case, the data were coming in as dictionaries within
# dictionaries - this function flattens them into a single dictionary
def flatten_dict(d, parent_key='', sep='_'):
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        elif isinstance(v, list):
            for i, item in enumerate(v):
                if isinstance(item, dict):
                    items.extend(flatten_dict(item, f"{new_key}_{i}", sep=sep).items())
                else:
                    items.append((f"{new_key}_{i}", item))
        else:
            items.append((new_key, v))
    return dict(items)


# fetch all data from the PNHP zotero library through the API
all_data = paginate_api(api_url)
# flatten data into dictionary without nested dictionaries
flattened_data = [flatten_dict(item) for item in all_data]

# create dataframe from the dictionary
df = pd.DataFrame(flattened_data)

# rename columns to match our columns
df1 = df.rename(columns={'meta_creatorSummary': 'creator_summary', 'meta_parsedDate': 'publication_year',
                         'data_itemType': 'item_type', 'data_title': 'title', 'data_abstractNote': 'abstract_note',
                         'data_publicationTitle': 'publication_title', 'data_volume': 'volume', 'data_issue': 'issue',
                         'data_pages': 'pages', 'data_url': 'data_url'})

# get list of all creator field names to prepare to combine all authors into one field delimited by comma
creator_list = []
for n in range(0, 21):
    creator_list.append("data_creators_{0}_lastName".format(n))
    creator_list.append("data_creators_{0}_firstName".format(n))

# create column that includes all authors separated by commas
df1['authors'] = df1[creator_list].apply(lambda x: ', '.join(x.dropna().astype(str)), axis=1)
df1['authors'] = df1['authors'].str.rstrip(', ')

# format publication year column
df1['publication_year'] = df1['publication_year'].str.slice(0, 4)

# get list of final columns to update in the Zotero reference feature service
final_columns = ['key','item_type','title','creator_summary','authors','publication_year','publication_title','volume','issue',
                'pages','data_url','abstract_note']
df_final = df1[final_columns]

# drop item types that don't meet the guidelines for inclusion
df_final = df_final.query('item_type != "annotation" and item_type != "note" and item_type != "attachment" and item_type != "computerProgram"')

# load gis credentials from OS environment variables - these need to be setup in your operating system environment variables
wpc_gis_username = os.environ.get("wpc_portal_username")
wpc_gis_password = os.environ.get("wpc_gis_password")
# connect to Portal account
gis = GIS('https://gis.waterlandlife.org/portal', wpc_gis_username, wpc_gis_password)

# get zotero ref feature layer object and delete all records
zotero_ref_flayer = FeatureLayer(zotero_ref_url)
zotero_ref_flayer.delete_features(where="objectid > 0")

# need to add full_citation column to make sure schema matches feature layer schema
df_final['full_citation'] = None
# create feature set and insert records into zotero reference feature layer
fs = df_final.spatial.to_featureset()
zotero_ref_flayer.edit_features(adds=fs)


# convert reference list to .csv - we don't need this, but we will keep it just in case.
# df_final.to_csv("H:/temp/zotero_ref.csv",index=False)

########################################################################################################################
## Calculate citation
########################################################################################################################

# this function is to get the HTML citation version
def get_citation(item_key):
    # Initialize the Zotero client
    zot = zotero.Zotero(library_id, library_type, api_key)

    # Get the item
    #item_key = row["key"]
    print(item_key)

    # Get the APA citation
    citation = zot.item(item_key, content='bib', style='apa')

    if citation:
        return citation
    else:
        pass

# get citation for all records in NHA references table based on zotero key
with arcpy.da.UpdateCursor(nha_reference_url, ["zotero_key", "full_cite"]) as cursor:
    for row in cursor:
        if row[0] is not None and row[1] is None:
            zotero_key = row[0]
            time.sleep(5) # this is so we don't error out the api
            a = get_citation(zotero_key)
            row[1] = a[0]
            cursor.updateRow(row)
        else:
            pass
