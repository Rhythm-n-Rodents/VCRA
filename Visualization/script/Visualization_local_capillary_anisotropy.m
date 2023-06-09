% Need to run Analysis_240_cube_whole_brain_stat_visualization_c5o2.m
% before running this script.
% This script is for visualizing the local network anisotropy. The
% reconstructed max projection is overlaid with 240 cube anisotropy
% significance and the projection of eigenvector of the largest eigenvalue
% of the correlation matrix of the link end to end orientation vector.
%% Task
vis_recon_proj_str = wholebrain_stat_str;
anisotropy_plot_cell = cell(4, 0);
anisotropy_plot_cell(:, end+1) = {wholebrain_stat_str.anisotropy_all_vw_fa, 'Volume_weighted_vessel_fractional_anisotropy', 'Fractional Anisotropy', wholebrain_stat_str.anisotropy_all_vw_vec};
anisotropy_plot_cell(:, end+1) = {wholebrain_stat_str.anisotropy_all_vw_fa_z, 'Volume_weighted_vessel_fractional_anisotropy_deviation_score', 'Fractional Anisotropy z-score', wholebrain_stat_str.anisotropy_all_vw_vec};
anisotropy_plot_cell(:, end+1) = {wholebrain_stat_str.anisotropy_all_vw_svd1, 'Volume_weighted_vessel_normalized_PC_value', 'Normalized principle value', wholebrain_stat_str.anisotropy_all_vw_vec};
% 
anisotropy_plot_cell(:, end+1) = {wholebrain_stat_str.anisotropy_cap_vw_fa, 'Volume_weighted_capillary_fractional_anisotropy', 'Fractional Anisotropy', wholebrain_stat_str.anisotropy_cap_vw_vec};
anisotropy_plot_cell(:, end+1) = {wholebrain_stat_str.anisotropy_cap_vw_fa_z, 'Volume_weighted_capillary_fractional_anisotropy_deviation_score', 'Fractional Anisotropy z-score', wholebrain_stat_str.anisotropy_cap_vw_vec};
anisotropy_plot_cell(:, end+1) = {wholebrain_stat_str.anisotropy_cap_vw_svd1, 'Volume_weighted_capillary_normalized_PC_value', 'Normalized principle value', wholebrain_stat_str.anisotropy_cap_vw_vec};

num_plot = size(anisotropy_plot_cell, 2);
vis_downsample_rate = 4;
save_layer_imageQ = false;

% valid_array_Q = (wb_capillary.num_data.length > 25) & (wb_capillary.num_data.length < 1000);
valid_array_Q = wb_capillary.num_data.length > 0;
%% Generate vedio
for vis_proj_direction = 1 : 3
    vis_layer_list = 1 : grid_info.grid_size(vis_proj_direction);
    vis_plan_dim = setdiff([1,2,3], vis_proj_direction);
    vis_proj_plane_name_list = {'horizontal', 'sagittal', 'coronal'};
    vis_proj_plane_name = vis_proj_plane_name_list{vis_proj_direction};
    starting_idx_3 = layer_list(1);
    end_idx_3 = layer_list(end);
    switch vis_proj_direction
        case 1
            vis_perm_order = [2,3,1];
            vis_mask_proj = permute(vis_recon_proj_str.mask_max_proj_1, vis_perm_order);
            grid_ll_1 = squeeze(grid_info.grid2D.ll_array(2, 1, :));
            grid_ll_2 = grid_info.gridZ.ll(starting_idx_3 : end_idx_3);
            [tmp_bbox_size_list_1, tmp_bbox_size_list_2] = ndgrid(grid_ll_1, grid_ll_2);
            proj_plane_grid_ll_list = cat(2, tmp_bbox_size_list_1(:), tmp_bbox_size_list_2(:));
            vis_sub_min = [1, grid_info.gridZ.mmxx(starting_idx_3, 1)];
        case 2
            vis_perm_order = [1,3,2];
            vis_mask_proj = permute(vis_recon_proj_str.mask_max_proj_2, vis_perm_order);
            grid_ll_1 = squeeze(grid_info.grid2D.ll_array(1, :, 1));
            grid_ll_2 = grid_info.gridZ.ll(starting_idx_3 : end_idx_3);
            [tmp_bbox_size_list_1, tmp_bbox_size_list_2] = ndgrid(grid_ll_1, grid_ll_2);
            proj_plane_grid_ll_list = cat(2, tmp_bbox_size_list_1(:), tmp_bbox_size_list_2(:));
            vis_sub_min = [1, grid_info.gridZ.mmxx(starting_idx_3, 1)];
        case 3
            vis_perm_order = [1,2,3];
            vis_mask_proj = vis_recon_proj_str.mask_max_proj_3;
            proj_plane_grid_ll_list = grid_info.grid2D.ll;
            vis_sub_min = [1, 1];
    end
    vis_subgrid_bbox_label_array = grid_info.bbox_grid_label_array(:, :, layer_list);
    vis_subgrid_bbox_label_array = permute(vis_subgrid_bbox_label_array, vis_perm_order);
    vis_im_cell = cell(grid_info.grid_size(vis_proj_direction), 1);
    for iter_layer = 1 : grid_info.grid_size(vis_proj_direction)
        vis_im_cell{iter_layer} = fun_stitch_patchs_with_overlap_with_bbox_info(vis_mask_proj(:, :, iter_layer), ...
            proj_plane_grid_ll_list, [32, 32], 'logical');
    end
    vis_folder_name = sprintf('240_cube_local_stat_%s', vis_proj_plane_name);
%%
    for vis_task_idx = 1 : num_plot
%         if ~any(vis_task_idx == [3, 4])
%             continue;
%         end        
        vis_data_array = permute(anisotropy_plot_cell{1, vis_task_idx}, vis_perm_order);
        ori_vec = anisotropy_plot_cell{4, vis_task_idx};
        ori_vec_cell = {squeeze(ori_vec(1, :, :, :)), squeeze(ori_vec(2, :, :, :)), squeeze(ori_vec(3, :, :, :))};
        ori_vec_cell = cellfun(@(x) permute(x, vis_perm_order), ori_vec_cell, 'UniformOutput', false);
        ori_vec_vis_1 = ori_vec_cell{vis_plan_dim(1)};
        ori_vec_vis_2 = ori_vec_cell{vis_plan_dim(2)};
        
        vis_valid_array_Q = permute(valid_array_Q, vis_perm_order);
        vis_data_array(~vis_valid_array_Q) = nan;
        ori_vec_vis_1(~vis_valid_array_Q) = nan;
        ori_vec_vis_2(~vis_valid_array_Q) = nan;
        
        % Fix the color bar limit for the whole brain
        vis_data_valid = vis_data_array(~isnan(vis_data_array));
        cbar_limit_low = prctile(vis_data_valid, 10);
        cbar_limit_high = prctile(vis_data_valid, 90);
        vis_opt = struct;
        vis_opt.folder_name = anisotropy_plot_cell{2, vis_task_idx};
        vis_opt.fig_name = anisotropy_plot_cell{2, vis_task_idx};
        vis_opt.color_bar_label = anisotropy_plot_cell{3, vis_task_idx};
        vis_opt.pixel_size = vis_downsample_rate;
        vis_opt.cbar_low = cbar_limit_low;
        vis_opt.cbar_high = cbar_limit_high;
        vis_opt.vis_figQ = false;
        vis_opt.return_frameQ = true;
        vis_opt.cbar_tick_lable = cellfun(@(x) num2str(x, '%.1e'),...
            num2cell(linspace(vis_opt.cbar_low, vis_opt.cbar_high, 11)), 'UniformOutput', false);
        vis_opt.video_file_name = sprintf('%s_%s_%s_%s.avi', dataset_name, stack, grid_info.version, vis_opt.fig_name);
        vis_opt.video_file_path = DataManager.fp_visualization_image(dataset_name, stack, vis_opt.video_file_name, fullfile(vis_folder_name, vis_opt.folder_name));
        vis_opt.cmap_name = 'winter';
        tmp_folder = fileparts(vis_opt.video_file_path);
        
        num_layer_to_plot = size(vis_data_array, 3);
        
        avi_str = VideoWriter(vis_opt.video_file_path);
        avi_str.FrameRate = 5;
        avi_str.Quality = 80;
        open(avi_str);
        for test_layer_idx = 1 : num_layer_to_plot
            tmp_layer = layer_list(test_layer_idx);
            fprintf('Writing frame %d/%d\n', test_layer_idx, num_layer_to_plot);
            vis_data_mat = vis_data_array(:, :, test_layer_idx);
            % Determine the position of the patches
            vis_layer_patch_idx = find(~isnan(vis_data_mat));
            patch_value = vis_data_mat(vis_layer_patch_idx);
            
            vis_layer_patch_label_mat = vis_subgrid_bbox_label_array(:, :, test_layer_idx);
            vis_layer_patch_label = vis_layer_patch_label_mat(vis_layer_patch_idx);
            vis_layer_bbox_mmxx = grid_info.bbox_xyz_mmxx_list(vis_layer_patch_label, :);
            vis_patch_bbox_xy = vis_layer_bbox_mmxx(:, [vis_plan_dim, vis_plan_dim + 3]);
            vis_patch_bbox_xy = vis_patch_bbox_xy - [vis_sub_min, vis_sub_min] + 1;
            % Scale the patches
            vis_patch_bbox_xy = ceil(vis_patch_bbox_xy ./ vis_opt.pixel_size);
            % Scale the image
            vis_im = vis_im_cell{test_layer_idx};
            vis_im_size = ceil(size(vis_im)./ vis_opt.pixel_size);
            vis_im = imresize(vis_im, vis_im_size, 'Method', 'nearest');
            % Output folder
            vis_opt.fig_title = sprintf('%s in grid layer %d', strrep(vis_opt.fig_name, '_', ' '), tmp_layer);
            vis_opt.file_name = sprintf('%s_%s_%s_layer_%d_%s.png', dataset_name, stack, grid_info.version, tmp_layer, vis_opt.fig_name);
            if save_layer_imageQ
                vis_opt.file_path = DataManager.fp_visualization_image(dataset_name, stack, vis_opt.file_name, fullfile(vis_folder_name, vis_opt.folder_name));
            end
            % Compute the 2D orientation vector
            tmp_ori_vec_2d_1 = ori_vec_vis_1(:, :, test_layer_idx);
            tmp_ori_vec_2d_2 = ori_vec_vis_2(:, :, test_layer_idx);
            tmp_ori_vec_1 = tmp_ori_vec_2d_1(vis_layer_patch_idx);
            tmp_ori_vec_2 = tmp_ori_vec_2d_2(vis_layer_patch_idx);
            % Scale the xy component
%             tmp_xy_vec_norm = sqrt(tmp_ori_vec_1 .^ 2 + tmp_ori_vec_2 .^ 2);
            % Normalize the 2D vector
            % tmp_ori_vec_1 = tmp_ori_vec_1 ./ tmp_xy_vec_norm ;
            % tmp_ori_vec_2 = tmp_ori_vec_2 ./ tmp_xy_vec_norm ;
            % Scale the 2D vector accoridng to local anisotropy
            % tmp_ori_vec_1 = tmp_ori_vec_1 ./ tmp_xy_vec_norm .* patch_v;
            % tmp_ori_vec_2 = tmp_ori_vec_2 ./ tmp_xy_vec_norm .* patch_v;
            ori_vec_2d_list = cat(2, tmp_ori_vec_1, tmp_ori_vec_2);
            
            layer_frame = fun_vis_single_section_local_network_orientation(vis_im, patch_value, ori_vec_2d_list, vis_patch_bbox_xy, vis_opt);
            writeVideo(avi_str, layer_frame);
        end
        close(avi_str)
    end
end
%% Color coded orientation
anisotropy_plot_cell = cell(4, 0);
anisotropy_plot_cell(:, end+1) = {wholebrain_stat_str.anisotropy_cap_vw_min2max_z, 'Volume_weighted_capillary_anisotropy_orientation', 'Isotropy', wholebrain_stat_str.anisotropy_cap_vw_vec};
anisotropy_plot_cell(:, end+1) = {wholebrain_stat_str.anisotropy_all_vw_min2max_z, 'Volume_weighted_vessel_anisotropy_orientation', 'Isotropy', wholebrain_stat_str.anisotropy_all_vw_vec};
num_plot = size(anisotropy_plot_cell, 2);
for vis_proj_direction = 1 : 3
    vis_layer_list = 1 : grid_info.grid_size(vis_proj_direction);
    vis_plan_dim = setdiff([1,2,3], vis_proj_direction);
    vis_proj_plane_name_list = {'horizontal', 'sagittal', 'coronal'};
    vis_proj_plane_name = vis_proj_plane_name_list{vis_proj_direction};
    starting_idx_3 = layer_list(1);
    end_idx_3 = layer_list(end);
    switch vis_proj_direction
        case 1
            vis_perm_order = [2,3,1];
            vis_mask_proj = permute(wholebrain_stat_str.mask_max_proj_1, vis_perm_order);
            grid_ll_1 = squeeze(grid_info.grid2D.ll_array(2, 1, :));
            grid_ll_2 = grid_info.gridZ.ll(starting_idx_3 : end_idx_3);
            [tmp_bbox_size_list_1, tmp_bbox_size_list_2] = ndgrid(grid_ll_1, grid_ll_2);
            proj_plane_grid_ll_list = cat(2, tmp_bbox_size_list_1(:), tmp_bbox_size_list_2(:));
            vis_sub_min = [1, grid_info.gridZ.mmxx(starting_idx_3, 1)];
        case 2
            vis_perm_order = [1,3,2];
            vis_mask_proj = permute(wholebrain_stat_str.mask_max_proj_2, vis_perm_order);
            %         grid_ll_1 = grid_info.grid2D.ll(1 : grid_info.grid2D.grid_size(1) , 1);
            grid_ll_1 = squeeze(grid_info.grid2D.ll_array(1, :, 1));
            grid_ll_2 = grid_info.gridZ.ll(starting_idx_3 : end_idx_3);
            [tmp_bbox_size_list_1, tmp_bbox_size_list_2] = ndgrid(grid_ll_1, grid_ll_2);
            proj_plane_grid_ll_list = cat(2, tmp_bbox_size_list_1(:), tmp_bbox_size_list_2(:));
            vis_sub_min = [1, grid_info.gridZ.mmxx(starting_idx_3, 1)];
        case 3
            vis_perm_order = [1,2,3];
            vis_mask_proj = wholebrain_stat_str.mask_max_proj_3;
            proj_plane_grid_ll_list = grid_info.grid2D.ll;
            vis_sub_min = [1, 1];
    end
    vis_subgrid_bbox_label_array = grid_info.bbox_grid_label_array(:, :, layer_list);
    vis_subgrid_bbox_label_array = permute(vis_subgrid_bbox_label_array, vis_perm_order);
    vis_im_cell = cell(grid_info.grid_size(vis_proj_direction), 1);
    for iter_layer = 1 : grid_info.grid_size(vis_proj_direction)
        vis_im_cell{iter_layer} = fun_stitch_patchs_with_overlap_with_bbox_info(vis_mask_proj(:, :, iter_layer), ...
            proj_plane_grid_ll_list, [32, 32], 'logical');
    end
    num_plot = size(anisotropy_plot_cell, 2);
    vis_folder_name = sprintf('240_cube_local_stat_%s', vis_proj_plane_name);
    for vis_task_idx = 1 : num_plot
        vis_data_array = permute(anisotropy_plot_cell{1, vis_task_idx}, vis_perm_order);
        ori_vec = anisotropy_plot_cell{4, vis_task_idx};
        ori_vec_cell = {squeeze(ori_vec(1, :, :, :)), squeeze(ori_vec(2, :, :, :)), squeeze(ori_vec(3, :, :, :))};
        ori_vec_cell = cellfun(@(x) permute(x, vis_perm_order), ori_vec_cell, 'UniformOutput', false);
        
        % Fix the color bar limit for the whole brain
        vis_data_valid = vis_data_array(~isnan(vis_data_array));
        cbar_limit_low = prctile(vis_data_valid, 10);
        cbar_limit_high = prctile(vis_data_valid, 90);
        vis_opt = struct;
        vis_opt.folder_name = sprintf('%s_color_coded', anisotropy_plot_cell{2, vis_task_idx});
        vis_opt.fig_name = sprintf('%s_color_coded', anisotropy_plot_cell{2, vis_task_idx});
        vis_opt.color_bar_label = anisotropy_plot_cell{3, vis_task_idx};
        vis_opt.pixel_size = vis_downsample_rate;
        vis_opt.cbar_low = cbar_limit_low;
        vis_opt.cbar_high = cbar_limit_high;
        vis_opt.vis_figQ = false;
        vis_opt.return_frameQ = true;
        vis_opt.cbar_tick_lable = cellfun(@(x) num2str(x, '%.1e'),...
            num2cell(linspace(vis_opt.cbar_low, vis_opt.cbar_high, 11)), 'UniformOutput', false);
        vis_opt.video_file_name = sprintf('%s_%s_%s_%s.avi', dataset_name, stack, grid_info.version, vis_opt.fig_name);
        vis_opt.video_file_path = DataManager.fp_visualization_image(dataset_name, stack, vis_opt.video_file_name, fullfile(vis_folder_name, vis_opt.folder_name));
        vis_opt.cmap_name = 'winter';
        tmp_folder = fileparts(vis_opt.video_file_path);
        
        num_layer_to_plot = size(vis_data_array, 3);
        
        avi_str = VideoWriter(vis_opt.video_file_path);
        avi_str.FrameRate = 5;
        avi_str.Quality = 80;
        open(avi_str);
        for test_layer_idx = 1 : num_layer_to_plot
            tmp_layer = layer_list(test_layer_idx);
            fprintf('Writing frame %d/%d\n', test_layer_idx, num_layer_to_plot);
            vis_data_mat = vis_data_array(:, :, test_layer_idx);
            % Determine the position of the patches
            vis_layer_patch_idx = find(~isnan(vis_data_mat));
            patch_value = vis_data_mat(vis_layer_patch_idx);
            
            vis_layer_patch_label_mat = vis_subgrid_bbox_label_array(:, :, test_layer_idx);
            vis_layer_patch_label = vis_layer_patch_label_mat(vis_layer_patch_idx);
            vis_layer_bbox_mmxx = grid_info.bbox_xyz_mmxx_list(vis_layer_patch_label, :);
            vis_patch_bbox_xy = vis_layer_bbox_mmxx(:, [vis_plan_dim, vis_plan_dim + 3]);
            vis_patch_bbox_xy = vis_patch_bbox_xy - [vis_sub_min, vis_sub_min] + 1;
            % Scale the patches
            vis_patch_bbox_xy = ceil(vis_patch_bbox_xy ./ vis_opt.pixel_size);
            % Scale the image
            vis_im = vis_im_cell{test_layer_idx};
            vis_im_size = ceil(size(vis_im)./ vis_opt.pixel_size);
            vis_im = imresize(vis_im, vis_im_size, 'Method', 'nearest');
            % Output folder
            vis_opt.fig_title = sprintf('%s in grid layer %d', strrep(vis_opt.fig_name, '_', ' '), tmp_layer);
            vis_opt.file_name = sprintf('%s_%s_%s_layer_%d_%s.png', dataset_name, stack, grid_info.version, tmp_layer, vis_opt.fig_name);
            if save_layer_imageQ
                vis_opt.file_path = DataManager.fp_visualization_image(dataset_name, stack, vis_opt.file_name, fullfile(vis_folder_name, vis_opt.folder_name));
            end
            % Compute the 2D orientation vector
            tmp_ori_vec_3d_1 = ori_vec_cell{1}(:, :, test_layer_idx);
            tmp_ori_vec_3d_2 = ori_vec_cell{2}(:, :, test_layer_idx);
            tmp_ori_vec_3d_3 = ori_vec_cell{3}(:, :, test_layer_idx);
            tmp_ori_vec_3d_1 = tmp_ori_vec_3d_1(vis_layer_patch_idx);
            tmp_ori_vec_3d_2 = tmp_ori_vec_3d_2(vis_layer_patch_idx);
            tmp_ori_vec_3d_3 = tmp_ori_vec_3d_3(vis_layer_patch_idx);
            
            ori_vec_3d_list = cat(2, tmp_ori_vec_3d_3, tmp_ori_vec_3d_2, tmp_ori_vec_3d_1);            
            layer_frame = fun_vis_single_section_local_network_orientation_by_color_code(vis_im, ori_vec_3d_list, vis_patch_bbox_xy, vis_opt);
            writeVideo(avi_str, layer_frame);
        end
        close(avi_str)
    end
end