FESOM data compression
======================

This repo contains code examples and description of ways how to compress FESOM data. For now we consider only netCDF compression, but leaverage new capabilities, that become available in netCDF 4.9.0.

#### TL;DR
- In netCDF 4.9.0 support for new compressions (fast an efficient) were added.
- To use it one have to install latest netCDF and couple of other libraries, since, for example `levante` do not have them in their modules. Good news is that it's easy to do it with conda.
- To work with compressed data in python (e.g. xarray) one also have to upgrade netCDF and install one or two libraries, but it should work smoothly.
- All result in up to 50% data reduction and improve the speed of parallel data processing, so probably worth the effort.

Installing necessary libs
------------------------

You should have your own installation of conda/mamba. It might work with conda provided by HPC, but I never tried it, so no garantee.

```bash
conda env create -f requirements-compress.yaml.yml
```
will create `compression` environment for you, that you should activate with:

```bash
conda activate compression
```

Now we have to setup a path to HDF plugins installed through `hdf5plugin` library. In my case the path looks like this:

```bash
export HDF5_PLUGIN_PATH='/work/ab0995/a270088/mambaforge/envs/cc/lib/python3.10/site-packages/hdf5plugin/plugins/'
```

Simple way to find out where your `hdf5plugin` library is installed is to run:
```bash
python -c "import hdf5plugin; print(hdf5plugin.__path__)"
```

Simple way
----------

Now you hopefully have everything set up. We are going to use simple `nccopy` to perform the compression. To compress using `zstd`:

```bash
nccopy -4 -F '*,32015,3' input.nc output.nc 
```

The `-4` means the output file will be netCDF4 format, and cryptic numbers after `-F` is actually your compression format. Here is the link to [Information on Registered Filter Plugins](https://portal.hdfgroup.org/display/support/Registered%252BFilter%252BPlugins). The `*` at the beggining means we compress all variables, so if you want to only compress one of them (e.g. ignoring coordinate variables), you can do `'salt,32015,3'`

So far we worked with:
* `*,32015,3` - zstd better compressions, a bit slower
* `*,32004,0` - lz4 a bit worse compression, but faster

There is a lot of work to explore what options could be better, but for now those two seems like a good starting point.

On 12 years of CORE2 data, results are:

|Uncompressed | lz4   | zstd |
|---------|-------|------|
| 63.6Gb  | 40.87Gb|36.67Gb|

We diecide to go for `zstd` for now, while `lz4` is something to explore as well.

For 13 years of 3M `D3` mesh:

|Uncompressed |  zstd | ratio|
|---------|------|-----------|
| 2139Gb  | 1327Gb| 0.62|

Additional thing you can do is to provide chunking options, like this:

```bash
nccopy -4 -c 'salt:5,5,10000'  -F '*,32004,0' input.nc output.nc 
```

This should improve your post processing, but we have to test it still.

Simplier way
-----------

You can use the `compress_data.sh` script from this repo. It will simply convert all `*.nc` files from one folder to another. The usage is:

```bash
./compress_data_parallel.sh  /INPUT/FOLDER /OUTPUT/FOLDER/ zstd 1
```

Options are `zstd` and `lz4`, the last argument is the number of parallel processes, that will be handled by [GNU parallel](https://www.gnu.org/software/parallel/)

Runing it in parallel seems to work pretty well - we can compress 13 years of D3 in just 7 minutes with 50 precesses. But PLEASE use compute nodes to do this, people on login nodes will thank you. On levante you can allocate ineractive session like this:

```bash
salloc --partition=compute --nodes=1 --time=03:00:00 --account abXXXX
```

Of course using batch mode is even better.

Although there are some simple checks done in the script, checking if everything is fine before deleting your original data is on you! :)

Advanced way
------------

We are working on more advanced solution, that will allow you have more control over how you compress your files, but it is still very much [work in progress](https://github.com/koldunovn/ccd)

Reading the files
=================

With command line utilities things seems to work fine as long as you have `HDF5_PLUGIN_PATH` pointing to the right place.

xarray
------

To make it work in xarray, you should add import of `hdf5plugin` to your scripts:

```python
import xarray as xr
import hdf5plugin

data = xr.open_mfdataset('./salt.fesom.*.nc')
data.salt[0,0,0].values
>> array(33.12693892)
```

dask
----

With dask you should add one more trick to make it work, when create the cluster:

```python
import xarray as xr
import hdf5plugin
from dask.distributed import Client
import dask

client = Client(n_workers=40, threads_per_worker=1, memory_limit='5GB')
client.run(hdf5plugin.register)
```

Test of 13 years of dask powered (40 workers, 5Gb each) TKE computation (`tke = 0.5*(uu+vv)`) for monthly `D3` data, show that with uncompressed data it takes 4 minutes, while with compressed (`zstd`) only 3m 20sec. So there is no degradation in compute time, but rather improvement.

Authors
=======

Nikolay Koldunov, with great help of Suvarchal Cheedela and Fabian Wachsmann.

