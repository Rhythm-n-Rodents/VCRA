# Vascular Connectome Reconstruction and Analysis
Computational pipeline for reconstructing and analyzing the vascular connectome from lumen-labeled two-photon vascular volumetric images. 

The pipeline is implemented in MATLAB 2019b and has been tested on Win 10, CentOS 7.6 and Ubuntu 18.04. 

## Setup
 - **Directory setting**: Setup the directories in `./Utilities/FileManager.m`. 
   1. `ROOT_PATH`: the absolute path to the root of the data folder. 
   2. `SCRIPT_PATH`: the absolute path to the root of the local script (this repository) folder.
   3. `EXTERNAL_LIB_ROOT_PATH`: the absolute path to the root of the external libraries. This folder contains third-party softwares for visualization, e.g. `itk-snap`. 
   4. `SCRATCH_ROOT_PATH`: the absolute path to the root of the scratch folder.
   5. `SERVER_ROOT_PATH`: the absolute path to the server / network drive that is mapped to a local directory. This is for accessing data not stored on the local hard drive. 
   6. `SERVER_SCRIPT_PATH`: the absolute path to the shared script on the server / network drive. This is for parallel computing using multiple machines.
- **Install third-party software**: 
   1. [`ITK-SNAP`](http://www.itksnap.org/pmwiki/pmwiki.php?n=Downloads.SNAP3): an open-source software for visualizing and annotating volumetric image data. After installation, please setup the directory to the executable file in `fp_itksnap_exe` of `./Utilities/FileManager.m/`. 

## Spatial graph representation of the vascular network
The spatial graph representation of the vascular network is stored as a MATLAB structure with the following fields: 
 - `num`: MATLAB structure with the following fields: 
   1. `mask_size`: 1 x 3 vector, size of the 3D array that holds the vascular network. The dimensions are in MATLAB subscript order and can be directly used for converting the linear indices of the voxels into the subscripts. 
   2. `mask_size_pad`: 1 x 3 vector, equals `mask_size + 2`. 
   3. `block_voxel`: scalar, number of voxels in the 3D array, equals `prod(mask_size)`. 
   4. `block_voxel_pad`: scalar, number of voxels in the padded 3D array, equals `prod(maks_size_pad)`.
   5. `neighbor_add_pad`: 26 x 1 vector, linear indices difference between a voxel and its 26 (3 x 3 x 3 - 1) neighboring voxels in the 3D array. 
   6. `neighbor_add_pad`: 26 x 1 vector, linear indices difference between a voxel and its 26 (3 x 3 x 3 - 1) neighboring voxels in the padded 3D array. 
   7. `skeleton_voxel`: scalar, number of vessel skeleton voxels. 
 - `link`: MATLAB structure with the following fields: 
   1. `num_cc`: scalar, number of link (vessel segment) connected components in the graph
   2. `cc_ind`: cell array, each cell contains the linear indices of the centerline voxels in the link, ordered from one end of the segment to an other end of the segment. The link connected components are labeled from 1 to `num_cc`. 
   3. `pos_ind`: column vector, generated by concatenating `link.cc_ind`. 
   4. `num_voxel`: number of link voxels in the graph 
   5. `num_voxel_per_cc`: number of voxels in each link connected component, i.e. number of elements in each cell of `cc_ind`. 
   6. `label`: column vector, link lables of the link voxels. 
   7. `map_ind_2_label`: sparse column vector, map the linear indices of link voxels to their link connected component labels. 
   8. `connected_node_label`: `num_cc`-by-2 array, labels of the connected nodes at the two ends (may not in the same order as the indices in `cc_ind`). `0` represents unconnected endpoints. 
   9.  `num_node`: column vector, number of connected nodes of each link. 
 - `node`: MATLAB structure with the following fields: 
   1. `num_cc`, `num_voxel`, `num_voxel_per_cc`, `label`, `map_ind_2_label`, `pos_ind` are defined the same as the ones in `link` for node connected component. 
   2. `cc_ind`: same as `link.cc_ind`, but the linear indices in each cell are not ordered. 
   3. `connected_link_label`: cell array, each cell contains the label of the link connected componet that the node is connected to. 
 - `isopoint`: MATLAB structure with the following fields: 
   1. `pos_ind` and `num_voxel` are defined the same as the ones in `link` for isolated centerline voxels. 
 - `isoloop`: MATLAB structure with the following fields: 
   1. `cc_ind`, `num_cc`, `pos_ind` are defined the same as the ones in `link` for isolated loop connected components. 
 - `endpoints`: MATLAB structure with the following fields:  
   1. `pos_ind`: column vector, linear indices of the link voxels with only one 26-neighbor centerline voxel
   2. `link_label`: column vector, label of the link connected component that the endpoint voxel belong to. 
   3. `num_voxel`: scalar, number of endpoint voxels. 
   4. `map_ind_2_label`: sparse column vector, map the linear indices of the endpoint voxels to their link connected component labels. 
 - `radius`: sparse column vector, map the linear indices of the centerline voxels to their radii. 

## Reference

    @article{Ji2021,
       title={Brain microvasculature has a common topology with local differences in geometry that match metabolic load},
       author={Ji, Xiang and Ferreira, Tiago and Friedman, Beth and Liu, Rui and Liechty, Hannah and Bas, Erhan and Chandrasheka, Jayaram and Kleinfeld, David}, 
       journal={Neuron},
       volume={109},
       number={7},
       pages={P1168-1187.E13},
       year={2021},
       publisher={Elsevier},
       url={https://doi.org/10.1016/j.neuron.2021.02.006}}

