import geopandas as gpd
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from shapely import Polygon, wkt


# CSV to GeoDataFrame - imports a CSV and converts it to a GeoDataFrame
#     assumes geometry column is called 'geometry'
def csv_gdf(fp, crs):
    df = pd.read_csv(fp, parse_dates=['datetime'])  # open CSV
    df['geometry'] = df['geometry'].apply(wkt.loads)  # load geometries
    gdf = gpd.GeoDataFrame(df, geometry='geometry', crs=crs)  # convert to GeoDataFrame
    return gdf


# Gridder - creates a grid over a given area based on the set height, width, and CRS
def gridder(area, h, w, crs):
    area = area.dissolve().to_crs(crs)  # dissolve and reproject area to desired CRS
    xmin, ymin, xmax, ymax = area.total_bounds  # get total bounds of the area
    xs = list(np.arange(xmin, xmax + w, w))  # create list of x values
    ys = list(np.arange(ymin, ymax + h, h))  # create list of y values
    polygons = []  # list for polygons
    for x in xs[:-1]:
        for y in ys[:-1]:
            polygons.append(Polygon([  # create and append polygon
                (x, y),  # bottom left
                (x + w, y),  # bottom right
                (x + w, y + h),  # top right
                (x, y + h)]))  # top left
    g = gpd.GeoDataFrame({'geometry': polygons}, crs=crs)  # create the grid GeoDataFrame
    g = g[g.centroid.intersects(area.geometry[0])]  # keep only grid cells whose centroids are in area
    # g = g[g.intersects(area.geometry[0])]  # keep only grid cells that are at least partially in the area
    return g


# Grid plotter - plots a grid
def grid_plotter(b, g):
    base = b.plot(alpha=0.2)
    g.plot(ax=base, facecolor='none', edgecolor='#707070')
    plt.show()

