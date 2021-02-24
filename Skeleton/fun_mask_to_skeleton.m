function image_mask = fun_mask_to_skeleton(image_mask)
% fun_mask_to_skeleton converts the 3D image mask to skeleton 
% Input: 
%   image_mask: 3D logical array
% Output:
%   image_mask: skeleton of the image_mask. 3D logical array

% Implemented according to Lee et al Building Skeleton Models via 3D-Medial
% Surface/Axis Thinning Algorithms 1994. The result should be identical to
% the MATLAB 2018a implement bwskel

% Load two look up table generated by generate_thinning_look_up_tables to
% replace all the checking before removal. 
persistent is_simple_point_removal_Q %#ok<PSET>
persistent is_removable_point_Q %#ok<PSET>
if isempty(is_simple_point_removal_Q)
    load('is_simple_point_removal_Q.mat'); %#ok<LOAD>
end
if isempty(is_removable_point_Q)
    load('is_removable_point_Q.mat'); %#ok<LOAD>
end

image_mask = padarray(image_mask, [1,1,1]);
mask_size = size(image_mask);
num_voxel = 27;
code_coeff = 2.^(0:num_voxel-2)';
unchangedBorders = 0;
while( unchangedBorders < 6 )  % loop until no change for all six border types
    unchangedBorders = 0;
    for currentBorder = 1:6 % loop over all 6 directions
        cands = false(mask_size);
        switch currentBorder
            case 4
                cands(2:end,:,:) = (image_mask(2:end,:,:) ~= image_mask(1:end-1,:,:));
            case 3
                cands(1:end-1,:,:) = (image_mask(1:end-1,:,:) ~= image_mask(2:end,:,:));
            case 1
                cands(:,2:end,:) = (image_mask(:,2:end,:) ~= image_mask(:,1:end-1,:));
            case 2
                cands(:,1:end-1,:) = (image_mask(:,1:end-1,:) ~= image_mask(:,2:end,:));
            case 6
                cands(:,:,2:end) = (image_mask(:,:,2:end) ~= image_mask(:,:,1:end-1));
            case 5
                cands(:,:,1:end-1) = (image_mask(:,:,1:end-1) ~= image_mask(:,:,2:end));
        end
        % make sure all candidates are indeed foreground voxels, since
        % actually many +1 voxels are not +1 in the original binary image. 
        cands = cands(:)==1 & image_mask(:)==1;
        noChange = true;
        if any(cands)
            cands = find(cands);
            nhood = fun_skeleton_get_neighbor_cube(image_mask,cands, 26, true);
            cands = cands(is_removable_point_Q(nhood * code_coeff + 1));
            if ~isempty(cands)
                for tmp_idx = 1 : length(cands)
                    voxel_ind = cands(tmp_idx);
                    nh = fun_skeleton_get_neighbor_cube(image_mask, voxel_ind, 26, true);
                    if is_simple_point_removal_Q(nh * code_coeff + 1)
                        image_mask(voxel_ind) = false;
                        noChange = false;
                    end
                end
            end
        end
        if( noChange )
            unchangedBorders = unchangedBorders + 1;
        end
    end
end
image_mask = image_mask(2:end-1, 2:end-1, 2:end-1);
end