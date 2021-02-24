function varargout = fun_vis_image_with_patch_and_contour(im, patch_v, patch_bbox_mmxx, contour_str, vis_opt)
% fun_vis_image_with_patch overlay patches on the image
% Input:
%   im: 2D numerical array, image
%   patch_v: 2D numerical array, value of the patch, that is mapped to the
%   patch color below.
%   patch_bbox_mmxx: N-by-4 numerical array, bounding box specifying the
%   cornor subscripts of the patch[min_1, min_2, max_1, max_2]
%   vis_opt: structure for formating the plot.
%%
% Check if the patch value is nan:
is_nan_Q = isnan(patch_v);
% Remvoe nan patch
patch_v = patch_v(~is_nan_Q);
% Compute bounding box patches vertices
bbox_vertices_X = patch_bbox_mmxx(~is_nan_Q, [2,4,4,2])';
bbox_vertices_Y = patch_bbox_mmxx(~is_nan_Q, [1, 1, 3, 3])';
%% Pixel size
if isfield(vis_opt, 'pixel_size') && isscalar(vis_opt.pixel_size)
    pixel_size = vis_opt.pixel_size;
else
    pixel_size = 1;
end
%% Colorbar and color map
if isfield(vis_opt, 'cbar_high') && isscalar(vis_opt.cbar_high)
    color_bar_limit_low = vis_opt.cbar_low;
    color_bar_limit_high = vis_opt.cbar_high;
else
    color_bar_limit_low = prctile(vis_data, 2);
    color_bar_limit_high = prctile(vis_data, 98);
end

if isfield(vis_opt, 'cmap_name') && ischar(vis_opt.cmap_name)
    cmap_name = vis_opt.cmap_name;
else
    cmap_name = 'jet';
end
[patch_v, ~, tmp_map] = real2rgb(patch_v, cmap_name, [color_bar_limit_low, color_bar_limit_high]);
if isfield(vis_opt, 'vis_figQ') && islogical(vis_opt.vis_figQ)
    vis_fig_Q = vis_opt.vis_figQ;
else
    vis_fig_Q = false;
end
im_size = [2700, 3600];
% im_size = size(im);
% im_size(2) = im_size(2) * 1.1;
% The position is in [ori_1, ori_2, width, height]
if vis_fig_Q
    fig_handle = figure('Position', [1, 1, im_size(2), im_size(1)], 'Visible', 'on');
else
    fig_handle = figure('Position', [1, 1, im_size(2), im_size(1)], 'Visible', 'off');
end
% Set up the axes object for overlay
im_ax = axes(fig_handle);
image(im_ax, im,'CDataMapping', 'scaled');
im_ax.Colormap = gray;
im_ax.Position = [0.075, 0.1, 0.8, 0.8];

im_ax.XAxis.Visible = 'off';
im_ax.YAxis.Visible = 'off';
% Add scale bar
scale_bar_y = im_ax.YLim(2) * 0.95;
scale_bar_x_1 = im_ax.XLim(2) * 0.95;
hold(im_ax, 'on');
sb_hdl = line(im_ax, scale_bar_x_1 - [vis_opt.scale_bar_length_pxl, 0], ...
    [scale_bar_y, scale_bar_y], 'LineWidth', 6, 'Color', 'w');
% im_ax.XLabel.String = 'Length/\mum';
% im_ax.YLabel.String = 'Length/\mum';
% im_ax.XAxis.TickLabels = cellfun(@(x) num2str(x, '%d'), ...
%     num2cell(im_ax.XAxis.TickValues .* pixel_size), 'UniformOutput', false);
% im_ax.YAxis.TickLabels = cellfun(@(x) num2str(x, '%d'), ...
%     num2cell(im_ax.YAxis.TickValues .* pixel_size), 'UniformOutput', false);

im_ax.DataAspectRatio = [1, 1, 1];
im_ax.FontSize = 24;
im_ax.FontWeight = 'bold';
% Axes setting
if isfield(vis_opt, 'fig_title') && ischar(vis_opt.fig_title)
    im_ax.Title.String = vis_opt.fig_title;
end
%% Draw patches
ax1 = axes(fig_handle);
linkprop([im_ax, ax1], {'Position', 'XLim', 'YLim', 'DataAspectRatio', 'YDir', 'XAxisLocation', ...
    'YAxisLocation'});
ax1.Visible = 'off';
if ~isempty(bbox_vertices_X)
    patch_hdl = patch(ax1, bbox_vertices_X, bbox_vertices_Y, patch_v, 'FaceAlpha', 0.5, 'LineStyle', 'none');
    %     patch_hdl.LineStyle = 'none';
end
cbar_obj = colorbar(ax1);
cbar_obj.Label.FontSize = 14;
if isfield(vis_opt, 'cbar_tick_lable') && iscell(vis_opt.cbar_tick_lable)
    cbar_obj.Ticks = linspace(cbar_obj.Limits(1), cbar_obj.Limits(2), numel(vis_opt.cbar_tick_lable));
    cbar_obj.TickLabels = vis_opt.cbar_tick_lable;
else
    cbar_obj.TickLabels = cellfun(@(x) num2str(x, '%.1e'),...
        num2cell(linspace(color_bar_limit_low, color_bar_limit_high, 11)), 'UniformOutput', false);
end
colormap(ax1, tmp_map)
if isfield(vis_opt, 'color_bar_label') && ~isempty(vis_opt.color_bar_label)
    cbar_obj.Label.String = vis_opt.color_bar_label;
end
cbar_obj.FontSize = 24;
% Control the size of the color bar
% cbar_obj.Position(1) = im_ax.Position(1) + im_ax.Position(3);
% cbar_obj.Position(2) = im_ax.Position(2);
% cbar_obj.Position(3) = 0.02;
% cbar_obj.Position(4) = im_ax.Position(4);
%% Draw contour
if ~isempty(contour_str)
    tmp_contour_sub = cat(1, contour_str.sub_cell{:});
    
    hold(ax1, 'on');
    for iter_contour = 1 : numel(tmp_contour_sub)
        tmp_sub = tmp_contour_sub{iter_contour};
        patch_hdl = patch(ax1, tmp_sub(:, 2), tmp_sub(:, 1), 1, 'FaceColor', 'none', ...
            'LineWidth', 1.5, 'LineStyle', '-');
    end
    
    % Add regional abbreviation
    % Compute center of mass from contour coordinate
    num_region = numel(contour_str.sub_cell);
    region_contour_com = zeros(2, num_region);
    num_coordiante_points = zeros(num_region, 1);
    for iter_region = 1 : num_region
        tmp_sub = contour_str.sub_cell{iter_region};
        tmp_sub = cat(1, tmp_sub{:});
        num_coordiante_points(iter_region) = size(tmp_sub, 1);
        region_contour_com(:, iter_region) = mean(tmp_sub, 1);
        text(ax1, region_contour_com(2, iter_region), region_contour_com(1, iter_region), ...
            contour_str.structure_abbrv{iter_region}, 'FontSize', 18, 'Color', 'w', 'HorizontalAlignment', 'center');
    end
end
%% Write image to folder
set(fig_handle, 'PaperPositionMode', 'auto');
if isfield(vis_opt, 'file_path') && ~isempty(vis_opt.file_path)
    fun_print_image_in_several_formats(fig_handle, vis_opt.file_path);
end
if nargout == 1
    if isfield(vis_opt, 'return_frameQ') && vis_opt.return_frameQ
        varargout{1} = getframe(fig_handle);
        close(fig_handle);
    elseif vis_fig_Q
        varargout{1} = fig_handle;
    end
elseif ~vis_fig_Q
    close(fig_handle);
    varargout{1} = 0;
end

end