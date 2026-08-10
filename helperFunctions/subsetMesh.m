%
%      usage: [verticesSubset,facesSubset] = subsetMesh(vertices,faces,whichVertices)
%         by: julien besle
%       date: 2020-04-02
%     inputs: vertices and faces of a 3D mesh and which vertices to keep
%    outputs: vertices and faces of a 3D mesh
%
%    purpose: reduces mesh to vertices specified in whichVertices 
%    either as a logical vector of same length as the input vertices
%    or as indices into the input vertices
%
function [verticesSubset,facesSubset] = subsetMesh(vertices,faces,whichVertices)

transposeVertices=false;
if size(vertices,2)~=3
  if size(vertices,1)==3
    vertices = vertices';
    transposeVertices=true;
  else
    error('(reduceMesh) vertices matrix must have only 3 elements in one of its dimensions');
  end
end
transposeFaces=false;
if size(faces,2)~=3
  if size(faces,1)==3
    faces = faces';
    transposeFaces=true;
  else
    error('(reduceMesh) faces matrix must have only 3 elements in one of its dimensions');
  end
end

if islogical(whichVertices) && size(vertices,1) == size(whichVertices,1)
  whichVertices = find(whichVertices);
end

%convert face index list to only include triangles containing these vertices
[~,whichFaces] = ismember(faces,whichVertices); 
facesSubset = whichFaces(all(whichFaces,2),:);
verticesSubset = vertices(whichVertices,:);

if transposeVertices
  verticesSubset = verticesSubset';
end
if transposeFaces
  facesSubset = facesSubset';
end
