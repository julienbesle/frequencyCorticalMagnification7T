% function  [correctedTotalArea, totalArea, faceArea, correctedFaceArea, vertexArea, correctedVertexArea] = meshSurfaceArea(V, F)
% Author: ChatGPT 4.0 + Julien Besle
% Date: 2025/05/21
%
% calculates the total area of a mesh, raw and uncorrected, as ell as area per face and vertex
%
% input:  - V: list of vertices
%         - F: list of faces/triangles
%
% output: - totalArea: Total raw mesh area. The is the total of the raw surface areas across all triangles
%         - correctedTotalArea: Total corrected mesh area. This is the total area, corrected for the elementwise flatness of the mesh using vertex curvature information
%         - faceArea: Per-triangle raw area
%         - correctedFaceArea-triangle corrected area: approximation of the corrected per-triangle area, using the average vertex-wise curvature correction term
%         - vertexArea: Per-vertex area contribution (will be unaccurate near any hole in the surface)
%         - correctedVertexArea: corrected per-vertex area contribution (will be unaccurate near any hole in the surface)


function [totalArea, correctedTotalArea, faceArea, correctedFaceArea, vertexArea, correctedVertexArea] = meshSurfaceArea(V, F, c)

    % Curvature correction coefficient
    if ~exist('c','var') || isempty(c)
      c = 1/3;
    end

    % Compute per-triangle raw area
    [faceArea, totalArea] = triangle_areas(V, F);
    
    % Estimate mean curvature and per-vertex area
    [H, vertexArea] = mean_curvature_and_area(V, F);
    
    % Total corrected area
    correction_term = sum(c * (H.^2) .* vertexArea);
    correctedTotalArea = totalArea + correction_term;

    % Map per-vertex correction back to per-triangle
    correctedFaceArea = apply_triangle_area_correction(F, H, vertexArea, faceArea, c);
    
    % correct per vertex as well
    correctedVertexArea = apply_vertex_area_correction(H, vertexArea, c);

    % correctedFaceArea = zeros(size(F,1),1);
    % for i = 1:size(F,1)
    %     verts = F(i,:);
    %     % Average of correction contributions from each vertex
    %     per_triangle_correction = c * mean(H(verts).^2 .* vertexArea(verts));
    %     correctedFaceArea(i) = faceArea(i) + per_triangle_correction;
    % end
end

function [A_tri, A_total] = triangle_areas(V, F)
    % Compute area of each triangle and total
    m = size(F,1);
    A_tri = zeros(m,1);
    for i = 1:m
        v1 = V(F(i,1),:);
        v2 = V(F(i,2),:);
        v3 = V(F(i,3),:);
        A_tri(i) = 0.5 * norm(cross(v2 - v1, v3 - v1));
    end
    A_total = sum(A_tri);
end

function [H, A_vertex] = mean_curvature_and_area(V, F)
    % Estimate mean curvature and area per vertex
    n = size(V,1);
    L = cotangent_laplacian(V, F);
    M = vertex_mass_matrix(V, F);
    
    % Mean curvature vector
    HV = L * V;
    H_mag = sqrt(sum(HV.^2, 2));
    A_vertex = full(sum(M, 2)); % Lumped mass = vertex area estimate
    
    H = 0.5 * H_mag; % Scalar mean curvature
end

function L = cotangent_laplacian(V, F)
    % Compute cotangent Laplacian
    n = size(V,1);
    L = sparse(n, n);
    
    for i = 1:size(F,1)
        idx = F(i,:);
        v = V(idx,:);
        
        for j = 1:3
            i1 = idx(j);
            i2 = idx(mod(j,3)+1);
            i3 = idx(mod(j+1,3)+1);
            
            u = V(i2,:) - V(i1,:);
            v1 = V(i3,:) - V(i1,:);
            v2 = V(i3,:) - V(i2,:);
            
            cot_alpha = cotangent_angle(u, v1);
            cot_beta  = cotangent_angle(-u, v2);
            
            L(i1,i2) = L(i1,i2) - cot_alpha;
            L(i2,i1) = L(i2,i1) - cot_alpha;
            
            L(i1,i1) = L(i1,i1) + cot_alpha;
            L(i2,i2) = L(i2,i2) + cot_alpha;
        end
    end
    L = 0.5 * L;
end

function c = cotangent_angle(u, v)
    % Cotangent of angle between vectors
    c = dot(u, v) / norm(cross(u, v));
end

function M = vertex_mass_matrix(V, F)
    % Lumped mass (area per vertex using barycentric area)
    n = size(V,1);
    M = sparse(n,n);
    
    for i = 1:size(F,1)
        idx = F(i,:);
        v1 = V(idx(1),:);
        v2 = V(idx(2),:);
        v3 = V(idx(3),:);
        
        area = 0.5 * norm(cross(v2 - v1, v3 - v1));
        for j = 1:3
            M(idx(j), idx(j)) = M(idx(j), idx(j)) + area / 3;
        end
    end
end

function A_tri_corrected = apply_triangle_area_correction(F, H, A_vertex, A_tri_raw, c)
% APPLY_TRIANGLE_AREA_CORRECTION_FIXED
% Applies curvature correction to triangle areas by distributing vertex
% corrections based on triangle adjacency.
%
% Inputs:
%   F          - Nx3 face matrix
%   H          - Vx1 mean curvature vector
%   A_vertex   - Vx1 per-vertex raw area
%   A_tri_raw  - Nx1 uncorrected triangle areas
%   c          - scalar correction factor
%
% Output:
%   A_tri_corrected - Nx1 corrected triangle areas

    % Ensure column vectors
    H = H(:);
    A_vertex = A_vertex(:);
    A_tri_raw = A_tri_raw(:);

    n_faces = size(F,1);
    n_verts = length(H);

    % Compute vertex correction
    vertex_correction = c * (H.^2) .* A_vertex;

    % Count how many triangles each vertex is part of
    vertex_face_count = accumarray(F(:), 1, [n_verts 1]);

    % Prevent divide-by-zero
    vertex_face_count(vertex_face_count == 0) = 1;

    % Distribute vertex corrections to triangles
    triangle_correction = zeros(n_faces, 1);
    for j = 1:3
        v_idx = F(:, j);
        % Distribute each vertex's correction to its triangle proportionally
        triangle_correction = triangle_correction + vertex_correction(v_idx) ./ vertex_face_count(v_idx);
    end

    % Final corrected area
    A_tri_corrected = A_tri_raw + triangle_correction;
end

function A_vertex_corrected = apply_vertex_area_correction(H, A_vertex, c)
% APPLY_VERTEX_AREA_CORRECTION Applies curvature correction to vertex area
%
% Inputs:
%   H        - Vx1 vector of mean curvature values at each vertex
%   A_vertex - Vx1 vector of raw per-vertex area contributions
%   c        - scalar curvature correction coefficient
%
% Output:
%   A_vertex_corrected - Vx1 vector of corrected per-vertex areas

    % Ensure column vectors
    H = H(:);
    A_vertex = A_vertex(:);

    % Compute correction
    A_vertex_corrected = A_vertex .* (1 + c * H.^2);
end
