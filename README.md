# CCA MAG Assembmly
- two sentences of background why we care about generating these genomes
- then the goal of the project, right now MAG assembly, identifying which MAG assembly pipeline is best

## File Structure
- make something similar to this, this is an example from one of my private repos, also take note that I moved stuff around

Info about each Directory:
```
coraDNA/
├── code/                          # Scripts and pipelines for analyses
├── data/                          # coraDNA data and metadata
│   ├── core-metadata/             # Metadata for each core
│   │   └── COR-example/           # Metadata specific to that core (e.g. luminescence banding, serial sample metadata)
│   └── non-core-specific-data/    # Non-core-specific data (e.g. historical climate of an area such as Varadero)
├── manuscripts/                   # Manuscript materials for published / in-prep manuscripts
├── protocols/                     # Established protocols (e.g. aDNA extraction, sclerochronology, drilling)
├── resources/                     # Resources useful for the coraDNA project (published papers, written materials, etc.)
├── CHANGELOG.md                   # A record of changes to this repository, automated by a snippet of code
├── README.md                      # This file :)
├── contributions.md               # A record of every individual that has contributed to the project and their contribution
└── .github/                       # GitHub configuration
    └── workflows/                 # Automated workflow to generate the changelog
```

## To Do
I will try to keep a To Do tasks list here, I will always try to keep the two focus items in the important callout box, also change this text to whatever you'd like so you know what leaves here


### High Priority
> [!IMPORTANT]
> Organize this readme
> Trim reads 

### Low Priority
- item a

## Methods
- write out what we've done, and why. Include DOIs for tools we've used. e.g.

### 1. Basecalling 
- minknow
- dorado supcall
- compared the results - dorado better, say why
- then talkl about the issues with the reads, they seem to require trimming. why do they explain it briefly

### 2. Trimming 
- 


