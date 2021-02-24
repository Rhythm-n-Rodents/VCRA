function [neighbor_link_label, varargout] = fun_graph_get_connected_link_label_by_link_label(vessel_graph, query_link_label, deg_sep)
% fun_graph_get_connected_link_label_by_link_label get the link label of
% the links that connected to the query link label.
% Input: 
%   vessel_graph: structure generated by fun_skeleton_to_graph
%   query_link_label: numerical vector, the label of links that we want to
%   get the neighbors 
%   deg_sep: degree of seperation, numerical scalar
% Output: 
%   neighbor_link_label: numerical vector
%
% Implemented by Xiang Ji on Jun 11, 2019

if nargin < 3
    deg_sep = 1;
end
assert(deg_sep >= 1, 'Deg_sep be a positive integer');
assert(all(query_link_label > 0, 'all'), 'Link label out of range');

connected_node_label = vessel_graph.link.connected_node_label(query_link_label, :);
connected_node_label = unique(connected_node_label(connected_node_label>0));
neighbor_link_label = unique(cat(1, vessel_graph.node.connected_link_label{connected_node_label(:)}));
% If order is greater than 1, recursively find the neighboring links 
if deg_sep > 1
   neighbor_link_label = fun_graph_get_connected_link_label_by_link_label(vessel_graph, neighbor_link_label, deg_sep - 1);    
end
if nargout > 1
    tmp_Q = false(vessel_graph.link.num_cc, 1);
    tmp_Q(neighbor_link_label) = true;
    % The following assertion can fail if the query link is a link with two
    % endpoints. 
%     assert(all(tmp_Q(query_link_label)), 'All query link should be in the neighbor link label list');
    varargout{1} = tmp_Q;
end