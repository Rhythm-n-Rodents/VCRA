function mask_skl = fun_skeleton_recentering(mask_skl, mask_int)
% fun_skeleton_recentering moves the skeleton generated by bwskel to the
% position of higher intensity
% Input:
%   mask_skl: 3 dimensional logical array, can be computed by
%   bwskel(mask_dt>0);
%   mask_int: 3d uint16 array, image.
% Output: 
%   mask_skl: 3 dimensional logical array of recentered skeleton
% Implemented by Xiang Ji on Dec 5, 2018
% Note/ To do list 
% 1. How to deal with nonremovable point that have larger distance
% transform neighbors
% 2. In this algorithm, the number of skeleton voxel can never increase.
% However, there is some case that when the center voxel is moved to the
% neighbor, more than one voxel need to be added. How to handle this
% situation while not adding extra voxels that change the Euler
% characteristic? 
% 3. It's possible that after recentering, the skeleton voxel is outside
% the mask that the skeleton was originally computed from.
% 4. When vessels are very bright, use distance transform to guide the
% recentering? - Should modify the input mask_int 
mask_skl = padarray(mask_skl, [1,1,1]);
mask_int = padarray(mask_int, [1,1,1]);

mask_size = size(mask_skl);
[tmp1, tmp2, tmp3] = ndgrid(1:3, 1:3, 1:3);
ind_add_coeff_27 = sub2ind(mask_size, tmp1, tmp2, tmp3);
ind_add_coeff_27 = ind_add_coeff_27 - ind_add_coeff_27(14);
ind_add_coeff_26 = ind_add_coeff_27([1:13, 15:27]');
% here load the 'is_removable_point_Q', which is a N-by-1 logical array
% precomputed for determining whether the center voxels can be removed or
% not in the new configuration. For more information about this array, see
% generate_thinning_look_up_tables
is_removable_point_Q = load('is_removable_point_Q.mat');
is_removable_point_Q = is_removable_point_Q.is_removable_point_Q;
ind_pos_code = 2.^(0:25);

active_voxel_ind = find(mask_skl);
num_changed_voxel = 1;
while num_changed_voxel > 0
    num_changed_voxel = 0;
    active_voxel_mask = false(mask_size);
    active_voxel_ind_new = zeros(26 * length(active_voxel_ind), 1);
    num_active_voxel = 0;
    num_cand_voxel = length(active_voxel_ind);
    active_voxel_neighbor_dt = mask_int(bsxfun(@plus, active_voxel_ind', ind_add_coeff_26));
    [~, active_voxel_neighbor_idx_sort] = sort(active_voxel_neighbor_dt, 1, 'descend');
    active_voxel_dt = mask_int(active_voxel_ind);
    
    for tmp_idx = 1 : num_cand_voxel
        % Get the neighbor
        tmp_ind = active_voxel_ind(tmp_idx);
        tmp_neighbor = mask_skl(tmp_ind + ind_add_coeff_26);
        tmp_neighbor_LUT_ind = (ind_pos_code * tmp_neighbor) + 1;
        if is_removable_point_Q(tmp_neighbor_LUT_ind)
            mask_skl(tmp_ind) = false;
            num_changed_voxel = num_changed_voxel + 1;
            tmp_neighbor_ind = tmp_ind + ind_add_coeff_26;
            for tmp_neighbor_idx = 1 : 26
                tmp_ind_1 = tmp_neighbor_ind(tmp_neighbor_idx);
                if tmp_neighbor(tmp_neighbor_idx)
                    if ~active_voxel_mask(tmp_ind_1)
                        active_voxel_mask(tmp_ind_1) = true;
                        num_active_voxel = num_active_voxel + 1;
                        active_voxel_ind_new(num_active_voxel) = tmp_ind_1;
                    end
                end
            end
        else
            % Find the neighbor with distance transform larger than the
            % center point but not in the skeleton. If more than one, sort
            % the neighbor indices with descending distrance transform.
%             tmp_neighbor_dist = mask_dt(tmp_ind + ind_add_coeff_26);
            tmp_neighbor_dist_gt_center = active_voxel_neighbor_dt(:, tmp_idx) > active_voxel_dt(tmp_idx) ;
            % Get the sorted neighbor index list according to the 26
            % neighbor distance transform
            tmp_sort_ind = active_voxel_neighbor_idx_sort(:, tmp_idx);
            for idx_1 = 1 : 26
                % Check neighbors from high to low
                test_neighbor_ind = tmp_sort_ind(idx_1);
                % Only check the neighbor that are not in the current
                % skeleton and is brighter than the current centeral
                % skeleton
                if ~tmp_neighbor(test_neighbor_ind) 
                    % Check if contains neighbors with higher intensity
                    if tmp_neighbor_dist_gt_center(test_neighbor_ind)
                    % If yes, check if the center point can be removed or
                    % not, after adding this candidate neighbor
                        if is_removable_point_Q(tmp_neighbor_LUT_ind + ind_pos_code(test_neighbor_ind))
                            % Test if the adding the brighter neighbor change
                            % the topology or not
                            tmp_neighbor_ind_to_add = tmp_ind + ind_add_coeff_26(test_neighbor_ind);
                            tmp_neighbor_neighbor = mask_skl(tmp_neighbor_ind_to_add + ind_add_coeff_26);
                            tmp_neighbor_LUT_id = (ind_pos_code * tmp_neighbor_neighbor) + 1;
                            if is_removable_point_Q(tmp_neighbor_LUT_id)
                                % Adding the neighbor does not change the
                                % original topology. Remove original center
                                % voxel and add neighbor voxel to the skeleton
                                mask_skl(tmp_ind) = false;
                                % Add new voxel
                                mask_skl(tmp_neighbor_ind_to_add) = true;
                                % Update active voxel
                                tmp_neighbor(test_neighbor_ind) = true;
                                % Update the active voxel list: All the
                                % neighbors of the removed voxels are recorded.
                                tmp_neighbor_ind = tmp_ind + ind_add_coeff_26;
                                for tmp_idx_1 = 1 : 26
                                    tmp_ind_2 = tmp_neighbor_ind(tmp_idx_1);
                                    if tmp_neighbor(tmp_idx_1)
                                        if ~active_voxel_mask(tmp_ind_2)
                                            active_voxel_mask(tmp_ind_2) = true;
                                            num_active_voxel = num_active_voxel + 1;
                                            active_voxel_ind_new(num_active_voxel) = tmp_ind_2;
                                        end
                                    end
                                end
                                % Neighbors of the added neighbor...
                                tmp_neighbor_ind = tmp_neighbor_ind_to_add + ind_add_coeff_26;
                                for tmp_idx_1 = 1 : 26
                                    tmp_ind_2 = tmp_neighbor_ind(tmp_idx_1);
                                    if tmp_neighbor_neighbor(tmp_idx_1) && tmp_ind_2 ~= tmp_ind
                                        if ~active_voxel_mask(tmp_ind_2)
                                            active_voxel_mask(tmp_ind_2) = true;
                                            num_active_voxel = num_active_voxel + 1;
                                            active_voxel_ind_new(num_active_voxel) = tmp_ind_2;
                                        end
                                    end
                                end
                                num_changed_voxel = num_changed_voxel + 1;
                                break
                            end
%                         else % If the center point is not removable... do nothing for now.
                        end
                    else
                        % All the rest of the neighboring indices have lower
                        % intensity, so no need to check. 
                        break;                    
                    end                    
                end
            end
        end
    end
    active_voxel_ind = active_voxel_ind_new(1 : num_active_voxel);
%     fprintf('Number of changed voxel: %d\n', num_changed_voxel);
%     fprintf('Number of active voxel: %d\n', num_active_voxel);
end
mask_skl = mask_skl(2:end-1, 2:end-1, 2:end-1);
end
