function exit_code = fun_generate_block_data_from_image_stack(image_stack, grid_info)
% fun_generate_block_data_from_image_stack crops image blocks specified by
% grid_info from the image_stack and write the image blocks to the disk.
% This function can be used if the entire image stack can be read into the
% memory.
% Input: 
%   image_stack: 3D numerical array
%   grid_info: structure generated by fun_get_grid_from_mask
% Output: 
%   exit_code: 0 if successed. 
% 
% Implemented by Xiang Ji on 04/17/2019
DataManager = FileManager; % MATLAB class for organizing data, can be replaced by 
dataset_name = grid_info.dataset_name;
stack = grid_info.stack;
grid_name = grid_info.version;
num_layer = grid_info.num_grid_layer;

assert(all(size(image_stack) == grid_info.data_size), 'The size of the image stack does not match the size of the grid');
task_tic = tic;
for iter_layer = 1 : num_layer
    tmp_tic = tic;
    tmp_bbox_xyz_mmll = grid_info.bbox_xyz_mmll{iter_layer}';
    tmp_num_bbox = grid_info.num_bbox_xy(iter_layer);
    tmp_bbox_grid_sub = grid_info.bbox_grid_sub{iter_layer}';
    for iter_bbox = 1 : tmp_num_bbox
        tmp_im_block = crop_bbox3(image_stack, tmp_bbox_xyz_mmll(:, iter_bbox));
        DataManager.write_block_data_file(tmp_im_block, dataset_name, stack, grid_name, ...
            tmp_bbox_grid_sub(1, iter_bbox), tmp_bbox_grid_sub(2, iter_bbox), tmp_bbox_grid_sub(3, iter_bbox));
    end
    fprintf('Finish generating block data for layer %d. Elpased time is %f seconds\n', ...
        iter_layer, toc(tmp_tic));
end
fprintf('Finish. Elapsed time is %f seconds\n', toc(task_tic));
exit_code = 0;
end