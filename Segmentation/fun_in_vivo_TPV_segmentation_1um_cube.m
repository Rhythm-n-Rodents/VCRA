function [vessel_mask, record] = fun_in_vivo_TPV_segmentation_1um_cube(block_data,seg_parameters)

record = struct;
record.parameters = seg_parameters;
voxel_length_um = seg_parameters.voxel_length_um;
%% Parameters
% Image enhancement
record.enhanced.ptl_low = 0.05;
record.enhanced.ptl_high = 1 - 1e-5;
% Background level estimation 
est_bg_std_coeff = 3; % 2 is used for the ML_2018_08_15;
% Rod filter
num_omega_step = seg_parameters.rod_filter_num_omega;
rod_radius = seg_parameters.rod_filter_radius_um ./ voxel_length_um;
rod_length = round(rod_radius * 6 + 1);
omega_step = pi/num_omega_step;
% Local maximum thresholding
min_half_max_intensity = 20000;
int_maxpooling_th_coeff = 0.3;
% Vesselness measure
% th_vesselness = seg_parameters.vesselness_th;
vessel_parameters.DoG_scale_list = seg_parameters.vesselness.DoG_scale_list_um./voxel_length_um;
vessel_parameters.input_normalized = true;
min_vesselness_th = seg_parameters.vesselness_th;
% min_vesselness_th = 0.005;

% Mask local adaptive thresholding
at_scale_1 = round(seg_parameters.adp_th_scale_1_um/voxel_length_um);
at_scale_2 = round(seg_parameters.adp_th_scale_2_um/voxel_length_um);
% Morphology
min_cc_size = seg_parameters.morp_min_cc_size;
% Max pooling size
max_pool_size = seg_parameters.max_pool_size;
% Assume all the voxels brighter than 0.5 * max_int are vessel voxels. -
% Might be wrong for the large surface vessels, where (near) saturation
% happens. 
% Minimum local intensity variance
min_bg_std = seg_parameters.min_bg_std;
%%
if isfield(seg_parameters, 'use_max_int_mask_Q')
    use_max_int_mask_Q = seg_parameters.use_max_int_mask_Q;
else
    use_max_int_mask_Q = true;
end

input_gpuArrayQ = isa(block_data, 'gpuArray');
if input_gpuArrayQ
    data_type = classUnderlying(block_data);
else
    data_type = class(block_data);
end
% Smooth the image and reduce the stitching artefact by median filter
block_data = single(medfilt3(block_data));
%% Estimate the background and image enhancement
block_size = size(block_data);
vascBlock = double(sort(block_data(block_data > 0), 'ascend'));
num_voxel = numel(vascBlock);
% The raw saturation ratio is recorded but not use for now. For weak
% saturation (to be defined later), the image is initially masked to be
% 65535/2
record.raw.saturation_ratio = nnz(vascBlock == intmax(data_type))/num_voxel;
if ~isempty(vascBlock)
    record.raw.int_min = vascBlock(1);
    record.raw.int_max = vascBlock(end);
    record.raw.dynamic_range = record.raw.int_max - record.raw.int_min;
    record.raw.bright_voxel_th = min((0.05*record.raw.dynamic_range + record.raw.int_min), 18000);
    record.raw.bright_voxel_ratio = nnz(vascBlock >= record.raw.bright_voxel_th)/num_voxel;
    if record.raw.bright_voxel_ratio < 0.1
        % Does not have large vessels occupying a large part of the cube
        record.raw.est_bg_ratio = max(eps, 1 - record.raw.bright_voxel_ratio - 0.1);
    else
        % Exist large vessles
        record.raw.est_bg_ratio = max(eps, 1 - record.raw.bright_voxel_ratio);
    end
    
    record.raw.est_bg = mean(vascBlock(1:ceil(num_voxel * record.raw.est_bg_ratio)));
    record.raw.est_bg_std = max(min_bg_std, std(vascBlock(1:ceil(num_voxel * record.raw.est_bg_ratio))));
    record.enhanced.int_low = vascBlock(max(1, round(record.enhanced.ptl_low * num_voxel)));
    record.enhanced.int_high = vascBlock(max(1, round(record.enhanced.ptl_high * num_voxel)));
    record.enhanced.dynamic_range = record.enhanced.int_high - record.enhanced.int_low;
    
    record.enhanced.est_bg = max(0, record.raw.est_bg - record.enhanced.int_low)/record.enhanced.dynamic_range;
    record.enhanced.est_bg_std = record.raw.est_bg_std / record.raw.dynamic_range;
    record.enhanced.est_bg_max = record.enhanced.est_bg + est_bg_std_coeff * record.enhanced.est_bg_std;
else
    vessel_mask = false(block_size);
    disp('Empty block');
    return;
end
% Enhance and normalize the image, convert it to single precision
vascBlock = max(gpuArray(block_data), record.enhanced.int_low);
vascBlock = (vascBlock - record.enhanced.int_low) ./ record.enhanced.dynamic_range;
%% Max-pooling based intensity threshold - For estimating the radius
% 0.35 is a very rough estimation of the edge intensity from the numerical
% simulation. Since we are more interested in the capillary diameters
% From the distance transform of the max intensity mask, the radius of some
% capillary is about 1.
% This mask is just for distance transform to read out the radius. 
vascBlock_maxpool = fun_downsample_by_block_operation(vascBlock, @max, max_pool_size);
vascBlock_maxpool = imgaussfilt3(vascBlock_maxpool, 1, 'FilterDomain', 'spatial');
if ndims(vascBlock_maxpool) == 3
    vascBlock_maxpool = imresize3(gather(vascBlock_maxpool), block_size);
elseif ismatrix(vascBlock_maxpool)
    vascBlock_maxpool = repelem(gather(vascBlock_maxpool), 1, 1, block_size(3));
    vascBlock_maxpool = imresize3(vascBlock_maxpool, block_size);
else
    error('vascBlock_maxpool is neither 3D array nor matrix');
end
int_mask = gather(vascBlock) > max(vascBlock_maxpool * int_maxpooling_th_coeff, record.enhanced.est_bg_max);
record.mask.est_volume_ratio = nnz(int_mask)/num_voxel;
%% Vesselness measure
% Rod enhanced filtering
[rod_filter_lib, rod_filter_orientation] = rod_filter_library(@rod_filter, rod_length, rod_radius, omega_step, [omega_step/2, pi], [omega_step/2, pi], true);
num_rod_filters = length(rod_filter_orientation);
rod_filter_lib = gpuArray(single(rod_filter_lib));
rod_response = zeros(block_size, 'like', vascBlock);
for rodIdx = 1 : num_rod_filters
    rod_response = max(rod_response, fun_imagefilter_FFT(vascBlock, rod_filter_lib(:,:,:,rodIdx)));
end
%% Hessian matrix based segmentation
vesselness = fun_multiscale_Frangi_vesselness(rod_response, vessel_parameters);
% To do: learn distance transform and use it to fill in the masked region,
% in order to compute a more accurate adaptive threshold
% adaptive_int_th_fill = fillmissing(adaptive_int_th, 'nearest');
th_vesselness_ptl = (1 - record.mask.est_volume_ratio + record.raw.saturation_ratio)*100;
if th_vesselness_ptl > 100
    th_vesselness = 0.1;
else
%     th_vesselness = max(prctile(vesselness(:), th_vesselness_ptl), 0.005);
    th_vesselness = max(prctile(vesselness(:), th_vesselness_ptl), min_vesselness_th);
end
record.mask.th_vesselness = gather(th_vesselness);
if use_max_int_mask_Q
    vesselness_mask = gather(vesselness > th_vesselness | block_data > max((record.raw.int_max/2), min_half_max_intensity) ) & int_mask;
else
    vesselness_mask = gather(vesselness > th_vesselness ) & int_mask;
end
%% Local adaptive thresholding for connecting the mask at the junctions
% at_strel = strel('sphere', 2);
% at_mask = ~imdilate(vesselness_mask, at_strel);
% at_mask = ~vesselness_mask;
[local_mean, local_std] = fun_masked_local_meanNstd(vascBlock, at_scale_1, ~vesselness_mask, 0);
adaptive_int_th = local_mean + 1.5 .* local_std;
[local_mean, local_std] = fun_masked_local_meanNstd(vascBlock, at_scale_2, ~vesselness_mask, 0);
adaptive_int_th = min(adaptive_int_th , local_mean + 2 .* local_std);
% tic
% adaptive_int_th = fun_regionfill(adaptive_int_th, ~at_mask);
% toc
% Manually set a hard maximum value for adaptive thresholding causes too
% much troubles. Many merge errors occur on the surface vessels
adaptive_int_mask = gather(vascBlock > adaptive_int_th & ...
    (local_std + vesselness_mask) > record.enhanced.est_bg_std);
% adaptive_int_mask = gather(vascBlock > adaptive_int_th & ...
%     (local_std + ~at_mask) > record.enhanced.est_bg_std);
adaptive_cc = bwconncomp(adaptive_int_mask, 26);
vessel_mask = false(block_size);
for cc_idx = 1 : adaptive_cc.NumObjects
    if any(vesselness_mask(adaptive_cc.PixelIdxList{cc_idx}))
        vessel_mask(adaptive_cc.PixelIdxList{cc_idx}) = true;
    end
end
% vessel_mask = vessel_mask;
%% Second round
% [local_mean, local_std] = fun_masked_local_meanNstd(vascBlock, at_scale_1, ~vessel_mask_1, 0);
% adaptive_int_th = local_mean + 1.5 .* local_std;
% [local_mean, local_std] = fun_masked_local_meanNstd(vascBlock, at_scale_2, ~vessel_mask_1, 0);
% adaptive_int_th = min(adaptive_int_th , local_mean + 2 .* local_std);
% adaptive_int_mask = gather(vascBlock > adaptive_int_th & ...
%     (local_std + vessel_mask_1) > record.enhanced.est_bg_std);
% % adaptive_int_mask = gather(vascBlock > adaptive_int_th & ...
% %     (local_std + vesselness_mask) > record.enhanced.est_bg_std);
% adaptive_cc = bwconncomp(adaptive_int_mask, 26);
% vessel_mask = false(block_size);
% for cc_idx = 1 : adaptive_cc.NumObjects
%     if any(vessel_mask_1(adaptive_cc.PixelIdxList{cc_idx}))
%         vessel_mask(adaptive_cc.PixelIdxList{cc_idx}) = true;
%     end
% end
% vessel_mask = vessel_mask | vessel_mask_1;
%% Remove small connected components
if min_cc_size > 0
    vessel_mask = bwareaopen(vessel_mask, min_cc_size);
end
if isa(vessel_mask, 'gpuArray')
    vessel_mask = gather(vessel_mask);
end
vessel_mask = imclose(vessel_mask, strel('sphere', 2));
%% 
% DataManager = FileManager;
% vis_mask = uint8(vessel_mask);
% vis_mask(vessel_mask & ~vesselness_mask) = 2;
% vis_mask(~vessel_mask & vesselness_mask) = 3;
% % DataManager.visualize_itksnap(gather(vascBlock), vis_mask);
% DataManager.visualize_itksnap(block_data, vis_mask);
end

