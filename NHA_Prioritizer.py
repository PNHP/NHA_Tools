# import system modules
import arcpy, os
import datetime
import pandas as pd
import numpy as np

# set tools to overwrite existing outputs
arcpy.env.overwriteOutput = True
# set environmental workspace to internal/temporary memory
arcpy.env.workspace = r'memory'

# set input parameters - paths to biotics and nha data
eo_sourcept = r"https://gis.waterlandlife.org/server/rest/services/PNHP/Biotics_READ_ONLY/FeatureServer/2"
eo_sourceln = r"https://gis.waterlandlife.org/server/rest/services/PNHP/Biotics_READ_ONLY/FeatureServer/3"
eo_sourcepy = r"https://gis.waterlandlife.org/server/rest/services/PNHP/Biotics_READ_ONLY/FeatureServer/4"
eo_ptreps = r"https://gis.waterlandlife.org/server/rest/services/PNHP/Biotics_READ_ONLY/FeatureServer/0"
nha_core = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/0"
visits = r"https://gis.waterlandlife.org/server/rest/services/PNHP/Biotics_READ_ONLY/FeatureServer/7"

# more input parameters - these are all needed for nha ranking
nha_species = r"https://gis.waterlandlife.org/server/rest/services/PNHP/NHA_EDIT/FeatureServer/6"
rounded_grank = r"https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/3"
rounded_srank = r"https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/4"
nha_rank_matrix = r"https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/2"
eorank_weights = r"https://gis.waterlandlife.org/server/rest/services/Hosted/NHA_Reference_Layers/FeatureServer/1"

# WeConserve layer
protected_lands = "https://gis.waterlandlife.org/server/rest/services/BaseLayers/We_Conserve_PA_Protected_Lands/FeatureServer/0"

# more intermediate parameters
input_features = [eo_sourceln, eo_sourcept, eo_sourcepy]  # feature class names of source lines, points, and polys
out_features = ['line', 'point', 'polygon']  # temporary centroid feature classes to be merged
output_feature = "Biotics_SourceFeature_centroids"  # filename of output centroid feature class

# define function to convert arcgis table to Pandas dataframe
def arcgis_table_to_pandas_df(table_path, field_names, where_clause=None):
    arr = arcpy.da.TableToNumPyArray(in_table=table_path, field_names=field_names, where_clause=where_clause)
    df = pd.DataFrame(arr)
    return df


# here we are creating centroids from source feature layers and merging the points, lines, and poly centroids together
merge_features = []  # empty list that will hold paths of temporary centroid feature classes to be merged
# enter into zipped loop including biotics source features as input
for in_feature, out_feature in zip(input_features, out_features):
    output = arcpy.FeatureToPoint_management(in_feature, out_feature, "INSIDE")
    arcpy.AddField_management(output, "feature_type", "TEXT", "", "", 8, "Feature Type")
    with arcpy.da.UpdateCursor(output, "feature_type") as cursor:
        for row in cursor:
            row[0] = out_feature
            cursor.updateRow(row)
    # add path of temporary centroid feature classes to merge_features list
    merge_features.append(output)
# merge centroid feature classes into one Biotics source feature centroid feature class
sf_centroids = arcpy.Merge_management(merge_features, os.path.join("memory", output_feature))
# join EO fields so that we can use EORANK and lastobs year for filtering purposes
arcpy.JoinField_management(sf_centroids,"EO_ID",eo_ptreps,"EO_ID",["LASTOBS","LASTOBS_YR","EORANK"])

# create SF centroids feature layer so we can select records that qualify for inclusion in an NHA
sf_centroids_lyr = arcpy.MakeFeatureLayer_management(sf_centroids,"sf_centroids")
year = datetime.datetime.now().year - 50
# this is the where clause for inclusion in an NHA - it is similar to the CPP where clause, but we exclude watch list species here
where_clause = "(((ELCODE LIKE 'AB%' AND LASTOBS >= '1990') OR (ELCODE = 'ABNKC12060' AND LASTOBS >= '1980')) OR (((ELCODE LIKE 'P%' OR ELCODE LIKE 'N%' OR ELCODE LIKE 'C%' OR ELCODE LIKE 'H%' OR ELCODE LIKE 'G%') AND (LASTOBS >= '{0}')) OR ((ELCODE LIKE 'P%' OR ELCODE LIKE 'N%') AND (USESA = 'LE' OR USESA = 'LT') AND (LASTOBS >= '1950'))) OR (((ELCODE LIKE 'AF%' OR ELCODE LIKE 'AA%' OR ELCODE LIKE 'AR%') AND (LASTOBS >= '1950')) OR (ELCODE = 'ARADE03011')) OR (((ELCODE LIKE 'AM%' OR ELCODE LIKE 'OBAT%') AND ELCODE <> 'AMACC01150' AND LASTOBS >= '1970') OR (ELCODE = 'AMACC01100' AND LASTOBS >= '1950') OR (ELCODE = 'AMACC01150' AND LASTOBS >= '1985')) OR (((ELCODE LIKE 'IC%' OR ELCODE LIKE 'IIEPH%' OR ELCODE LIKE 'IITRI%' OR ELCODE LIKE 'IMBIV%' OR ELCODE LIKE 'IMGAS%' OR ELCODE LIKE 'IP%' OR ELCODE LIKE 'IZ%') AND LASTOBS >= '1950') OR (ELCODE LIKE 'I%' AND ELCODE NOT LIKE 'IC%' AND ELCODE NOT LIKE 'IIEPH%' AND ELCODE NOT LIKE 'IITRI%' AND ELCODE NOT LIKE 'IMBIV%' AND ELCODE NOT LIKE 'IMGAS%' AND ELCODE NOT LIKE 'IP%' AND ELCODE NOT LIKE 'IZ%' AND LASTOBS >= '1980'))OR (LASTOBS = '' OR LASTOBS = ' ')) AND (EO_TRACK = 'Y') AND (LASTOBS <> 'NO DATE' AND EORANK <> 'X' AND EORANK <> 'X?' AND EST_RA <> 'Very Low' AND EST_RA <> 'Low' AND INDEP_SF <> 'Y')".format(
    year)
sf_centroids_lyr = arcpy.SelectLayerByAttribute_management(sf_centroids_lyr, "NEW_SELECTION", where_clause)

# tabulate intersect between the NHA layer and SF centroids to see which centroids are within NHAs
sf_nha_intersect = arcpy.analysis.TabulateIntersection(in_zone_features = nha_core,
                                                       zone_fields = "nha_join_id",
                                                       in_class_features = sf_centroids_lyr,
                                                       out_table = os.path.join("memory","sf_nha_intersect"),
                                                       class_fields = "SF_ID"
                                                       )

# join back the drawn date into the intersect so we can compare to visits
arcpy.JoinField_management(sf_nha_intersect, "nha_join_id", nha_core, "nha_join_id", "drawn_date")

# convert sf nha intersect to pandas dataframe to do calculations
sf_nha_intersect_fields = [f.name for f in arcpy.ListFields(sf_nha_intersect)]
sf_nha_df = arcgis_table_to_pandas_df(sf_nha_intersect, sf_nha_intersect_fields)

# convert visits to pandas dataframe to do calculations
visits_fields = [f.name for f in arcpy.ListFields(visits)]
visits_df = arcgis_table_to_pandas_df(visits, visits_fields)

# convert sf_centroids to pandas dataframe for join
sf_fields = [f.name for f in arcpy.ListFields(sf_centroids_lyr) if f.name != arcpy.Describe(sf_centroids_lyr).shapeFieldName] # exclude the shape fields
sf_df = arcgis_table_to_pandas_df(sf_centroids_lyr, sf_fields)

# convert eo_ptreps to pandas dataframe for join
eo_fields = [f.name for f in arcpy.ListFields(eo_ptreps) if f.name != arcpy.Describe(eo_ptreps).shapeFieldName] # exclude the shape fields
eo_df = arcgis_table_to_pandas_df(eo_ptreps, eo_fields)

# outer join of sf_nha_intersect and visits to get visits that intersect NHAs
visits_nha_merge = pd.merge(visits_df, sf_nha_df, on='SF_ID', how='outer')

# join in sf attributes
visits_sf_merge = pd.merge(visits_nha_merge, sf_df, on='SF_ID', how='left')

# join in eo attributes
merge_final = pd.merge(visits_sf_merge, eo_df[["EO_ID","SURVEY_YR"]], on='EO_ID', how='left')

# Replace None with NaN
merge_final = merge_final.fillna(np.nan)
merge_final = merge_final.replace({np.nan: None})

# if SF does not have visit (aka visit year is null), fill with survey year to get last approximate visit
merge_final['VISIT_YR'] = merge_final['VISIT_YR'].fillna(merge_final['SURVEY_YR'])
# remove rows with NO DATE / that do not have a valid survey/visit date/year
merge_final = merge_final[merge_final['VISIT_YR'] != 0]

# convert visit year to date field
merge_final['VISIT_YR_date'] = pd.to_datetime(merge_final['VISIT_YR'], format='%Y')

# this needed to be done to drop nas in the next line
pd.options.mode.copy_on_write = True

# drop any records that have a NULL nha_join_id - this subsets records that intersect NHAs and leaves out centroids that do not intersect NHAs
nha_visits = merge_final.dropna(subset=['nha_join_id'])

# create column designating if visit is after drawn update
nha_visits['visits_after'] = np.where(nha_visits['VISIT_YR_date'] > nha_visits['drawn_date'], 1, 0)
# create column designating if visit is before drawn update
nha_visits['visits_before'] = np.where(nha_visits['VISIT_YR_date'] > nha_visits['drawn_date'], 0, 1)

# calculate year statistics
visits_after = nha_visits.groupby('nha_join_id')['visits_after'].sum().to_frame().reset_index() # this is to get the number of visits after the NHA drawn date
visits_before = nha_visits.groupby('nha_join_id')['visits_before'].sum().to_frame().reset_index() # this is to get the number of visits before the NHA drawn date
mean_visit_yr = nha_visits.groupby('nha_join_id')['VISIT_YR'].mean().to_frame().reset_index() # get the mean visit year
mean_visit_yr.rename(columns={'VISIT_YR': 'mean_visit_yr'}, inplace=True)
median_visit_yr = nha_visits.groupby('nha_join_id')['VISIT_YR'].median().to_frame().reset_index() # get the median visit year
median_visit_yr.rename(columns={'VISIT_YR': 'med_visit_yr'}, inplace=True)
max_visit_yr = nha_visits.groupby('nha_join_id')['VISIT_YR'].max().to_frame().reset_index() # get the max visit year
max_visit_yr.rename(columns={'VISIT_YR': 'max_visit_yr'}, inplace=True)
min_visit_yr = nha_visits.groupby('nha_join_id')['VISIT_YR'].min().to_frame().reset_index() # get the min visit year
min_visit_yr.rename(columns={'VISIT_YR': 'min_visit_yr'}, inplace=True)


# create Pandas dataframes from NHA species list and reference tables
species_df = arcgis_table_to_pandas_df(nha_species,["EO_ID", "SNAME", "SCOMNAME", "ELSUBID", "GRANK", "SRANK",
                                                    "EORANK", "exclude", "nha_join_id"])
grank_df = arcgis_table_to_pandas_df(rounded_grank, ["grank", "grank_rounded"])
srank_df = arcgis_table_to_pandas_df(rounded_srank, ["srank", "srank_rounded"])
nha_matrix_df = arcgis_table_to_pandas_df(nha_rank_matrix, ["grank", "srank", "combinedrank", "score"])
eorank_df = arcgis_table_to_pandas_df(eorank_weights, ["eorank", "weight"])

# only keep records that meet NHA criteria
species_df = species_df[species_df['exclude'] == 'N']

# do a bunch of joins to get combined grank/srank scores and eo weights into the species list
species_df = pd.merge(species_df, grank_df, how='left', left_on="GRANK", right_on="grank") # join rounded grank to species list
species_df = pd.merge(species_df, srank_df, how='left', left_on="SRANK", right_on="srank") # join rounded srank to species list
species_df = pd.merge(species_df, eo_df[["EO_ID","ELCODE","LASTOBS_YR"]], how='left', on='EO_ID')
species_df = species_df.drop_duplicates(subset=['nha_join_id', 'EO_ID'])

species_df['combinedrank'] = species_df["grank_rounded"] + species_df["srank_rounded"] # concatenate grank and srank to get combined rank
species_df = pd.merge(species_df, nha_matrix_df[["combinedrank", "score"]], how='left', left_on="combinedrank",
                      right_on="combinedrank") # join rank score to species list based on combined rank
species_df.score = pd.to_numeric(species_df["score"]).fillna(0) # fill score with 0 if it is Null
species_df = pd.merge(species_df, eorank_df, how='left', left_on="EORANK", right_on="eorank") # join eorank score to species list

# calculate the weighted rank score by multiplying the combined rank score by the eo weight
species_df["weighted_score"] = species_df["score"] * species_df["weight"]
species_df.weighted_score = pd.to_numeric(species_df["weighted_score"]).fillna(0) # fill Null values with 0

# get nha site score by summing the weighted scores of EOs within the NHA
nha_site_score = species_df.groupby('nha_join_id')['weighted_score'].sum().to_frame().reset_index()
nha_site_score.rename(columns={'weighted_score': 'nha_site_score'}, inplace=True)

# get number of species per NHA
num_species = species_df.groupby('nha_join_id')['ELSUBID'].nunique().to_frame().reset_index()
num_species.rename(columns={'ELSUBID': 'count_species'}, inplace=True)


# get number of EOs per NHA
num_eos = species_df.groupby('nha_join_id')['EO_ID'].nunique().to_frame().reset_index()
num_eos.rename(columns={'EO_ID': 'count_EOs'}, inplace=True)


# getting % protected lands
# first need to project WeConservePA layer to Albers
# define albers projection that we will use for all calculations
albers_str = r'PROJCS["alber",GEOGCS["GCS_North_American_1983",DATUM["D_North_American_1983",SPHEROID["GRS_1980",6378137.0,298.257222101]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Albers"],PARAMETER["false_easting",0.0],PARAMETER["false_northing",0.0],PARAMETER["central_meridian",-78.0],PARAMETER["standard_parallel_1",40.0],PARAMETER["standard_parallel_2",42.0],PARAMETER["latitude_of_origin",39.0],UNIT["Meter",1.0]];-16085300 -8515400 279982320.962027;-100000 10000;-100000 10000;0.001;0.001;0.001;IsHighPrecision'
albers_prj = arcpy.SpatialReference()
albers_prj.loadFromString(albers_str)

# check for transformations between input data and albers projection. if any exist, set them for output transformations
input_sr = arcpy.Describe(nha_core).spatialReference
transformations = arcpy.ListTransformations(input_sr, albers_prj)
if len(transformations) == 0:
    transformation = ""
else:
    transformation = transformations[0]

# set output environment to albers projection and transformation if it exists
arcpy.env.outputCoordinateSystem = albers_prj
arcpy.env.geographicTransformations = transformation

# first dissolve protected lands layer so that we don't end up getting funky numbers over 100%
protected_lands_dissolve = arcpy.Dissolve_management(protected_lands, os.path.join("memory","protected_lands_dissolve"))
protected_land_intersect = arcpy.TabulateIntersection_analysis(nha_core, "nha_join_id", protected_lands_dissolve, os.path.join("memory", "protected_land_intersect"))

# convert sf nha intersect to pandas dataframe to do calculations
protected_intersect_fields = [f.name for f in arcpy.ListFields(protected_land_intersect)]
protected_lands_df = arcgis_table_to_pandas_df(protected_land_intersect, protected_intersect_fields)
protected_lands_df.rename(columns={'PERCENTAGE': 'percent_protected'}, inplace=True)


## CALCULATING BOTANY STATS
plant_species = species_df.loc[species_df["ELCODE"].str.startswith('P', na=False)]

# get nha PLANT site score by summing the weighted scores of EOs within the NHA
plant_score = plant_species.groupby('nha_join_id')['weighted_score'].sum().to_frame().reset_index()
plant_score.rename(columns={'weighted_score': 'BOTANY_weighted_score'}, inplace=True)

# get number of species per NHA
num_plant_species = plant_species.groupby('nha_join_id')['ELSUBID'].nunique().to_frame().reset_index()
num_plant_species.rename(columns={'ELSUBID': 'BOTANY_count_species'}, inplace=True)

# get number of species per NHA
num_plant_eos = plant_species.groupby('nha_join_id')['EO_ID'].nunique().to_frame().reset_index()
num_plant_eos.rename(columns={'EO_ID': 'BOTANY_count_EOs'}, inplace=True)

# get count of s1s2s3 species per NHA
count_s1s2s3_species = plant_species[(plant_species['srank_rounded'] == 'S1') | (plant_species['srank_rounded'] == 'S2') | (plant_species['srank_rounded'] == 'S3')].groupby('nha_join_id')['ELSUBID'].nunique().to_frame().reset_index()
count_s1s2s3_species.rename(columns={'ELSUBID': 'BOTANY_count_S1S2S3_species'}, inplace=True)

# get count of s1s2s3 eos per NHA
count_s1s2s3_eos = plant_species[(plant_species['srank_rounded'] == 'S1') | (plant_species['srank_rounded'] == 'S2') | (plant_species['srank_rounded'] == 'S3')].groupby('nha_join_id')['EO_ID'].nunique().to_frame().reset_index()
count_s1s2s3_eos.rename(columns={'EO_ID': 'BOTANY_count_S1S2S3_EOs'}, inplace=True)


# get last_obs max, min, mean for plants
mean_lastobs_plants = plant_species.groupby('nha_join_id')['LASTOBS_YR'].mean().to_frame().reset_index() # get the mean lastobs year
mean_lastobs_plants.rename(columns={'LASTOBS_YR': 'BOTANY_mean_lastobs_yr'}, inplace=True)

median_lastobs_plants = plant_species.groupby('nha_join_id')['LASTOBS_YR'].median().to_frame().reset_index() # get the median lastobs year
median_lastobs_plants.rename(columns={'LASTOBS_YR': 'BOTANY_med_lastobs_yr'}, inplace=True)

max_lastobs_plants = plant_species.groupby('nha_join_id')['LASTOBS_YR'].max().to_frame().reset_index() # get the max lastobs year
max_lastobs_plants.rename(columns={'LASTOBS_YR': 'BOTANY_max_lastobs_yr'}, inplace=True)

min_lastobs_plants = plant_species.groupby('nha_join_id')['LASTOBS_YR'].min().to_frame().reset_index() # get the min lastobs year
min_lastobs_plants.rename(columns={'LASTOBS_YR': 'BOTANY_min_lastobs_yr'}, inplace=True)

# get list of sites with high granked species
plant_species['BOTANY_high_grank'] = np.where(((plant_species['grank_rounded']=="G1") | (plant_species['grank_rounded']=="G2") | (plant_species['grank_rounded']=="G3")) & (plant_species['SNAME'] != "Panax quinquefolius") & (plant_species['SNAME'] != "Hydrastis canadensis") & (plant_species['SNAME'] != "Crataegus pennsylvanica"), 1, 0)
high_grank = plant_species.groupby(['nha_join_id'])['BOTANY_high_grank'].sum().to_frame().reset_index()

# convert sf_centroids to pandas dataframe for join
#nha_fields = ["nha_join_id", "sig_rank"] # exclude the shape fields
#nha_list = arcgis_table_to_pandas_df(nha_core, nha_fields)

# DO A BUNCH OF STUFF TO JOIN ALL THE METRICS INTO ONE DATAFRAME
#final_metrics = pd.merge(nha_list, nha_site_score, how='left', on='nha_join_id')
final_metrics = nha_site_score
final_metrics["nha_score_percentile"] = final_metrics["nha_site_score"].rank(pct=True, method='min')
final_metrics = pd.merge(final_metrics, num_species, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, num_eos, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, visits_before, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, visits_after, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, min_visit_yr, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, mean_visit_yr, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, max_visit_yr, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, protected_lands_df[["nha_join_id","percent_protected"]], how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, plant_score, how='left', on='nha_join_id')
final_metrics["BOTANY_score_percentile"] = final_metrics["BOTANY_weighted_score"].rank(pct=True, method='min')
final_metrics = pd.merge(final_metrics, num_plant_species, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, num_plant_eos, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, count_s1s2s3_species, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, count_s1s2s3_eos, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, min_lastobs_plants, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, mean_lastobs_plants, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, max_lastobs_plants, how='left', on='nha_join_id')
final_metrics = pd.merge(final_metrics, high_grank, how="left", on="nha_join_id")

# Define function to fill with botany tiers
def fill_botany_tiers(row):
    if (row['BOTANY_count_S1S2S3_species'] > 6) | (row['BOTANY_weighted_score'] > 350):
        return 'Tier 1'
    elif 2 < row['BOTANY_count_S1S2S3_species'] <= 6:
        return 'Tier 2'
    elif row['BOTANY_count_S1S2S3_species'] == 1:
        return 'Tier 2.5'
    elif pd.isnull(row['BOTANY_weighted_score']):
        return np.nan
    else:
        return 'Tier 3'

# Apply the function to create a new column 'C'
final_metrics['BOTANY_tier'] = final_metrics.apply(fill_botany_tiers, axis=1)

# fill null values with 0 in certain columns
cols_to_fill = ['nha_site_score', 'nha_score_percentile', 'count_species', 'count_EOs', 'percent_protected',
                'BOTANY_weighted_score', 'BOTANY_count_species', 'BOTANY_count_EOs', 'BOTANY_count_S1S2S3_species',
                'BOTANY_count_S1S2S3_EOs', 'BOTANY_high_grank']
final_metrics[cols_to_fill] = final_metrics[cols_to_fill].fillna(0)

final_metrics[["update_priority","update_type","taxa_target"]] = np.nan

final_metrics.to_csv(r'H://temp//nha_prioritization.csv', index=False)


# Get EO score by multiplying EO weight together for all records in NHA
# Group by 'group' and apply the multiplication function
# we're not going to use this right now
# def multiply_group(group):
#     return np.prod(group)
# eo_score = species_df.groupby('nha_join_id')['weight'].apply(multiply_group)

# Get rarity weighted richness score for EO
# we're not going to use this right now
# elcode_nha_intersect = arcpy.analysis.TabulateIntersection(in_zone_features = nha_core,
#                                                        zone_fields = "nha_join_id",
#                                                        in_class_features = sf_centroids_lyr,
#                                                        out_table = os.path.join("memory","sf_nha_intersect"),
#                                                        class_fields = "ELSUBID"
#                                                        )
# elcode_count = arcpy.Statistics_analysis(elcode_nha_intersect, os.path.join("memory", "elcode_count"), [["ELSUBID", "COUNT"]], "ELSUBID")
# elcode_count_fields = [f.name for f in arcpy.ListFields(elcode_count)]
# elcode_count_df = pd.DataFrame((row for row in arcpy.da.SearchCursor(elcode_count, elcode_count_fields)),
#                            columns=elcode_count_fields)
#
# elcode_count_df["rarity_score"] = 1 / elcode_count_df["COUNT_ELSUBID"]
#
# # merge in rarity score to species list
# species_df = pd.merge(species_df, elcode_count_df, how='left', on="ELSUBID")
# rwr_overall = species_df.groupby('nha_join_id')['rarity_score'].sum()
