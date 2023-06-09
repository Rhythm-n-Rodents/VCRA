function exit_code = fun_graph_write_subblock_skeleton(vessel_graph, force_overwrite_Q)
% fun_graph_write_subblock_skeleton use the information in the vessel_graph
% to compute the skeleton and radius in the subblock and save to the hard
% drive
% Input: 
%   vessel_graph: structure generated by fun_skeleton_to_graph originally,
%   with additional fields 'radius' and 'info'. For example, see
%   Annotation_pipeline_test_20190220.m
% Output: 
%   exit_code: 0 if success. 
% Implemented by Xiang Ji on 02/22/2019
% 
% Modified by Xiang Ji on 03/08/2019
% 1. Check if the file to be wrote is already exist. If yes, use distance
% transform to determine the region of the skeleton that need to be
% updated, save the two skeleton structure into backup (field of the structure)
% and update the skeleton indices, radius, distance to the boundary
% accordingly. 
if nargin < 2
    force_overwrite_Q = false;
end
DataManager = FileManager;
dataset_name = vessel_graph.info.dataset_name;
stack = vessel_graph.info.stack;
grid_name = vessel_graph.info.sub_grid_version;
%% Construct the skeleton array
image_size = vessel_graph.num.mask_size;
vessel_skl = zeros(image_size, 'single');
skl_ind = cat(1, vessel_graph.link.pos_ind, vessel_graph.node.pos_ind, vessel_graph.isopoint.pos_ind);
skl_r = single(full(vessel_graph.radius(skl_ind)));
vessel_skl(skl_ind) = skl_r;
%%
sub_grid_sub = vessel_graph.info.sub_grid_sub;
sub_grid_ind = vessel_graph.info.sub_grid_ind;
sub_grid_global_bbox_mmxx = vessel_graph.info.sub_grid_global_bbox_mmxx;
sub_grid_global_bbox_mmll = vessel_graph.info.sub_grid_global_bbox_mmll;

sub_grid_local_bbox_mmxx = sub_grid_global_bbox_mmxx - [vessel_graph.info.bbox_mmxx(1:3), vessel_graph.info.bbox_mmxx(1:3)] + 1;
sub_grid_local_bbox_mmll = sub_grid_local_bbox_mmxx;
sub_grid_local_bbox_mmll(:, 4:6) = sub_grid_local_bbox_mmxx(:, 4:6) - sub_grid_local_bbox_mmxx(:, 1:3) + 1;
num_valid_sub_grid = numel(sub_grid_ind);

combined_grid_mmxx_grid = vessel_graph.info.combined_grid_mmxx_grid;
combined_grid_size = combined_grid_mmxx_grid(4:6) - combined_grid_mmxx_grid(1:3) + 1;
% Compute the distance between each subblock to the boundary, 1 if on the
% boundary. 
dist_to_boudanry_pad = false(combined_grid_size);
dist_to_boudanry_pad = padarray(dist_to_boudanry_pad, [1,1,1], true);
dist_to_boudanry_pad = bwdist(dist_to_boudanry_pad);
dist_to_boundary_pad_size = size(dist_to_boudanry_pad);

sub_grid_sub_min = combined_grid_mmxx_grid(1:3);
n26_ind_add_pad = fun_skeleton_neighbor_add_coeff_3D(dist_to_boundary_pad_size, 26, false);
n6_ind_add_pad = fun_skeleton_neighbor_add_coeff_3D(dist_to_boundary_pad_size, 6, false);
for iter_sub_grid = 1 : num_valid_sub_grid
    tmp_idx_1 = sub_grid_sub(iter_sub_grid, 1);
    tmp_idx_2 = sub_grid_sub(iter_sub_grid, 2);
    tmp_layer = sub_grid_sub(iter_sub_grid, 3);
    tmp_fp = DataManager.fp_block_skl_file(dataset_name, stack, grid_name, ...
        tmp_idx_1, tmp_idx_2, tmp_layer);
    
    tmp_subgrid_sub = sub_grid_sub(iter_sub_grid, :) - sub_grid_sub_min + 1;
    tmp_subgrid_sub_pad = tmp_subgrid_sub + 1;
    tmp_sub_grid_ind_pad = sub2ind(dist_to_boundary_pad_size, tmp_subgrid_sub_pad(1), ...
        tmp_subgrid_sub_pad(2), tmp_subgrid_sub_pad(3));
    tmp_dist_to_boudary_27 = dist_to_boudanry_pad(tmp_sub_grid_ind_pad + n26_ind_add_pad);
    tmp_dist_to_boundary_7 = dist_to_boudanry_pad(tmp_sub_grid_ind_pad + n6_ind_add_pad);

    if isfile(tmp_fp) && ~force_overwrite_Q
        tmp_exist_str = load(tmp_fp);
        tmp_exist_dist_to_boundary_27 = tmp_exist_str.dist_2_boundary_27;
        % The current skeleton is more reliable than the existing one in
        % i-th direction if the following vector is positive in the i-th
        % element. 
        tmp_dir_to_update = tmp_dist_to_boudary_27 - tmp_exist_dist_to_boundary_27;
        tmp_dir_to_update_cube = reshape(tmp_dir_to_update, 3,3,3);
        if all(tmp_dir_to_update <= 0) && ~force_overwrite_Q
            fprintf('No need to update the skeleton in the block. Skip...\n');
            continue;
        end
    end
    tmp_skl = crop_bbox3(vessel_skl, sub_grid_local_bbox_mmll(iter_sub_grid, :), 'default');
    tmp_block_size = sub_grid_local_bbox_mmll(iter_sub_grid, 4:6);
    tmp_skl_ind = uint32(find(tmp_skl > 0));
    tmp_skl_r = tmp_skl(tmp_skl_ind);
    
    tmp_str = struct;
    tmp_str.dataset_name = vessel_graph.info.dataset_name;
    tmp_str.stack = vessel_graph.info.stack;
    tmp_str.grid_name = grid_name;
    tmp_str.dataset_size = vessel_graph.info.dataset_size;
    tmp_str.global_bbox_mmxx = sub_grid_global_bbox_mmxx(iter_sub_grid, :);
    tmp_str.global_bbox_mmll = sub_grid_global_bbox_mmll(iter_sub_grid, :);
    tmp_str.idx_1 = tmp_idx_1;
    tmp_str.idx_2 = tmp_idx_2;
    tmp_str.layer = tmp_layer;
    tmp_str.block_size = tmp_block_size;
    tmp_str.ind = tmp_skl_ind;
    tmp_str.r = tmp_skl_r;
    tmp_str.dist_2_boundary_27 = tmp_dist_to_boudary_27;
    tmp_str.dist_2_boundary_7 = tmp_dist_to_boundary_7;
    if (~isfile(tmp_fp) || force_overwrite_Q) 
        % If the file does not exist, or in forced overwrite mode, write
        % the new skeleton directly
        DataManager.write_block_skl_file(tmp_str, tmp_str.dataset_name, tmp_str.stack, tmp_str.grid_name, ...
            tmp_str.idx_1, tmp_str.idx_2, tmp_str.layer);
    else
        %% If need to merge
        % Compute the distance transform for an intermediate size of mask,
        % then scale the size of the mask up to save time in distance
        % transform.
        tmp_dt_mask_size = round(tmp_block_size ./ 4);
        tmp_mask_update = int8(imresize3(tmp_dir_to_update_cube, tmp_dt_mask_size, 'nearest'));
        [~, tmp_mask_middle_nearest_idx] = bwdist(tmp_mask_update ~= 0);
        tmp_nearest_label = tmp_mask_update(tmp_mask_middle_nearest_idx);
        tmp_mask_update(tmp_nearest_label > 0) = 1;
        tmp_mask_update(tmp_nearest_label < 0) = -1;
        tmp_mask_update = imresize3(tmp_mask_update, tmp_block_size, 'nearest');
%         implay(rescale(tmp_mask_update))
        % Backup the two skeleton structure before merging
        if ~isfield(tmp_exist_str, 'backup')
            backup = {tmp_exist_str; tmp_str};
        else
            tmp_exist_str_wo_bk = rmfield(tmp_exist_str, 'backup');
            backup = cat(1, tmp_exist_str.backup, tmp_exist_str_wo_bk, tmp_str);
        end
        % Merge skeleton and radius
        tmp_current_valid_Q = tmp_mask_update(tmp_skl_ind) > 0;
        tmp_exist_valid_Q = tmp_mask_update(tmp_exist_str.ind) < 0;
        % There the skeleton voxels are unordered in any sense. 
        tmp_merge_skl_ind = cat(1, tmp_skl_ind(tmp_current_valid_Q), tmp_exist_str.ind(tmp_exist_valid_Q));
        tmp_merge_skl_r = cat(1, tmp_skl_r(tmp_current_valid_Q), tmp_exist_str.r(tmp_exist_valid_Q));
        
        tmp_str.ind = tmp_merge_skl_ind;
        tmp_str.r = tmp_merge_skl_r;
        
        tmp_str.dist_2_boundary_27 = max(tmp_dist_to_boudary_27, tmp_exist_str.dist_2_boundary_27);
        tmp_str.dist_2_boundary_7 = max(tmp_dist_to_boundary_7, tmp_exist_str.dist_2_boundary_7);
        
        tmp_str.backup = backup;
        DataManager.write_block_skl_file(tmp_str, dataset_name, stack, grid_name, ...
            tmp_idx_1, tmp_idx_2, tmp_layer);
    end
end
exit_code = 0;
end