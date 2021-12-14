## Model Descriptions
Please refer to jupyter notebook file for desc and output explanation. 

## Additional Files
convert_minizinc: python script that converts output from symbolic execution to data file (data.dzn) to be used for minizinc. 
`python3 convert_minizinc.py tdma.txt dataflow.xml`

## Running using docker

First you can download the git repo somewhere,

```
git clone git@github.com:katwinkl3/Scheduling-CP.git
```

Then you can pull the minizinc docker,

```
docker pull minizinc/minizinc  
```

Finally you can run the docker over your folder,

```
docker run -it --rm -v /path/to/Scheduling-CP/:/mnt  minizinc/minizinc minizinc --solver Gecode /mnt/cons_model.mzn /mnt/data.dzn
```
