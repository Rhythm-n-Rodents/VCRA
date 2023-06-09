function sub_graph = fun_graph_get_subgraph_by_node_label(input_graph, node_label)
% fun_graph_get_subgraph_by_node_label construct the subset of the graph
% consisted of specified nodes
% Input: 
%   input_graph: structure generated by fun_skeleton_to_graph
%   node_label: numerical vector, the label of the nodes for extracting the
%   subgraph
% Output: 
%   sub_graph: subset of the input graph 
% Notice:
% 1. The isopoints are ignored here. 
% Implemented by Xiang Ji on 02/18/2019
num_new_node = numel(node_label);
map_node_label_old_to_new = zeros(input_graph.node.num_cc + 1, 1);
map_node_label_old_to_new(node_label + 1) = 1 : num_new_node;

sub_graph = struct;
sub_graph.num = input_graph.num;
sub_graph.node.cc_ind = input_graph.node.cc_ind(node_label);

sub_graph.node.connected_link_label = input_graph.node.connected_link_label(node_label);

tmp_old_link_label = unique(cat(1, sub_graph.node.connected_link_label{:}), 'sorted');
num_new_link = numel(tmp_old_link_label);
map_link_label_old_to_new = zeros( tmp_old_link_label(end)+1, 1);
map_link_label_old_to_new(tmp_old_link_label+1) = 1 : num_new_link;

sub_graph.link.cc_ind = input_graph.link.cc_ind(tmp_old_link_label);
sub_graph.link.connected_node_label = input_graph.link.connected_node_label(tmp_old_link_label, :);
% Update node labels
sub_graph.link.connected_node_label = map_node_label_old_to_new(sub_graph.link.connected_node_label  + 1);
% Update link labels 
for iter_node = 1 : num_new_node
    tmp_link_label = map_link_label_old_to_new(sub_graph.node.connected_link_label{iter_node} + 1);
    sub_graph.node.connected_link_label{iter_node} = tmp_link_label(tmp_link_label > 0);
end
sub_graph.endpoint = input_graph.endpoint;
% Add derivative fields
sub_graph = fun_graph_add_graph_derivative_fileds(sub_graph);
end