# mesh_data_exporter.py
bl_info = {
    "name": "Mesh Data Exporter",
    "author": "Your Name",
    "version": (1, 0),
    "blender": (4, 2, 0),
    "location": "File > Export",
    "description": "Export mesh data: vertices, colors, UVs, normals, and tangents",
    "category": "Import-Export",
}

import bpy
import bmesh
import struct
import os
from mathutils import Vector, Matrix
from bpy_extras.io_utils import ExportHelper
from bpy.props import StringProperty, BoolProperty, EnumProperty
from bpy.types import Operator
from typing import Tuple, List, Dict, Any


def extract_mesh_data(obj) -> Tuple[List[List[float]], List[List[float]], List[List[float]], List[List[float]], List[List[float]], List[int]]:
    """
    Extract mesh data from a Blender object.
    
    Args:
        obj: A Blender object with mesh data
        
    Returns:
        Tuple containing:
        - vertex_positions: List of [x, y, z] coordinates for each vertex
        - vertex_colors: List of [r, g, b, a] colors for each vertex
        - tex_coords: List of [u, v] texture coordinates for each vertex
        - normals: List of [x, y, z] normal vectors for each vertex
        - tangents: List of [x, y, z, w] tangent vectors for each vertex
        - indices: List of vertex indices
    """
    # Ensure we're working with a mesh object
    if obj.type != 'MESH':
        raise ValueError("Object must be a mesh")
    
    # Get the object's world transformation matrix
    world_matrix = obj.matrix_world
    
    # Create a temporary mesh with modifiers applied
    depsgraph = bpy.context.evaluated_depsgraph_get()
    object_eval = obj.evaluated_get(depsgraph)
    mesh_eval = object_eval.to_mesh()
    
    # Create BMesh representation
    bm = bmesh.new()
    bm.from_mesh(mesh_eval)
    
    # Ensure we have access to all the data we need
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    
    # Create lists to store mesh data
    vertex_positions = []
    vertex_colors = []
    tex_coords = []
    normals = []
    tangents = []
    indices = []
    
    # Check for UV maps
    uv_layer = None
    if len(bm.loops.layers.uv) > 0:
        uv_layer = bm.loops.layers.uv.active
    
    # Check for color attributes (changed in Blender 4.x)
    color_layer = None
    color_attr = None
    
    # First try the new color attributes system (Blender 4.x)
    if hasattr(mesh_eval, "color_attributes") and len(mesh_eval.color_attributes) > 0:
        for color_attr in mesh_eval.color_attributes:
            if color_attr.domain == 'CORNER':  # Use CORNER domain (similar to per-loop)
                color_attr = color_attr.name
                break
    # Fall back to the older vertex colors system
    elif hasattr(bm.loops.layers, "color") and len(bm.loops.layers.color) > 0:
        color_layer = bm.loops.layers.color.active
    
    # Create mapping dictionary for vertex data
    vertex_map = {}
    current_index = 0
    
    # Process faces to extract indices and per-face-vertex data
    for face in bm.faces:
        face_indices = []
        for loop in face.loops:
            vert = loop.vert
            
            # Get vertex position (already transformed by matrix_world)
            position = world_matrix @ vert.co
            
            # Get normal (transformed by world matrix)
            normal = world_matrix.to_3x3() @ vert.normal
            normal.normalize()
            
            # Get UV
            uv = loop[uv_layer].uv if uv_layer else Vector((0.0, 0.0))
            
            # Get color - handle both old and new color systems
            if color_layer:
                color = loop[color_layer]
                color_tuple = (color[0], color[1], color[2], 1.0)
            else:
                color_tuple = (1.0, 1.0, 1.0, 1.0)
            
            # Create a unique key for this vertex data
            vertex_key = (
                vert.index,
                tuple(uv) if uv_layer else None,
                tuple(normal),
                color_tuple if color_layer else None
            )
            
            # Check if we've seen this exact vertex data before
            if vertex_key in vertex_map:
                # Reuse the existing vertex
                face_indices.append(vertex_map[vertex_key])
            else:
                # Add new vertex data
                vertex_map[vertex_key] = current_index
                face_indices.append(current_index)
                current_index += 1
                
                # Store the data
                vertex_positions.append([position.x, position.y, position.z])
                normals.append([normal.x, normal.y, normal.z])
                tex_coords.append([uv.x, uv.y] if uv_layer else [0.0, 0.0])
                vertex_colors.append(list(color_tuple))
        
        # Add face indices to the index list (triangulate if needed)
        if len(face_indices) == 3:
            indices.extend(face_indices)
        elif len(face_indices) == 4:
            # Simple triangulation for quads
            indices.extend([face_indices[0], face_indices[1], face_indices[2]])
            indices.extend([face_indices[0], face_indices[2], face_indices[3]])
        else:
            # Triangulate n-gons
            for i in range(1, len(face_indices) - 1):
                indices.extend([face_indices[0], face_indices[i], face_indices[i + 1]])
    
    # Calculate tangents
    # In Blender 4.2, tangent calculation is handled differently
    tangents = [[1.0, 0.0, 0.0, 1.0] for _ in range(len(vertex_positions))]
    
    # Use the mesh's built-in tangent calculation if available
    if len(mesh_eval.uv_layers) > 0:
        # Ensure tangents are calculated
        mesh_eval.calc_tangents()
        
        # Map vertices to the mesh loops that use them
        vert_to_loops = {}
        for poly in mesh_eval.polygons:
            for loop_idx in poly.loop_indices:
                vert_idx = mesh_eval.loops[loop_idx].vertex_index
                if vert_idx not in vert_to_loops:
                    vert_to_loops[vert_idx] = []
                vert_to_loops[vert_idx].append(loop_idx)
        
        # Transfer tangent data to our vertices
        for vertex_key, idx in vertex_map.items():
            vert_idx = vertex_key[0]
            if vert_idx in vert_to_loops and vert_to_loops[vert_idx]:
                # Get the first loop associated with this vertex
                loop_idx = vert_to_loops[vert_idx][0]
                loop = mesh_eval.loops[loop_idx]
                
                # Get the tangent and transform it
                tangent = world_matrix.to_3x3() @ loop.tangent
                tangent.normalize()
                bitangent_sign = loop.bitangent_sign
                
                tangents[idx] = [tangent.x, tangent.y, tangent.z, bitangent_sign]
    
    # Clean up
    object_eval.to_mesh_clear()
    bm.free()
    
    return vertex_positions, vertex_colors, tex_coords, normals, tangents, indices


class ExportMeshData(Operator, ExportHelper):
    """Export mesh data including vertices, colors, UVs, normals and tangents"""
    bl_idname = "export.mesh_data"  
    bl_label = "Export Mesh Data"
    bl_options = {'PRESET'}

    # ExportHelper mixin class uses this
    filename_ext = ".mesh"

    filter_glob: StringProperty(
        default="*.mesh",
        options={'HIDDEN'},
        maxlen=255,  # Max internal buffer length, longer would be clamped.
    )

    # Export options
    export_selection: BoolProperty(
        name="Selection Only",
        description="Export selected objects only",
        default=False,
    )
    
    export_colors: BoolProperty(
        name="Export Colors",
        description="Export vertex colors",
        default=True,
    )
    
    export_uvs: BoolProperty(
        name="Export UVs",
        description="Export texture coordinates",
        default=True,
    )
    
    export_normals: BoolProperty(
        name="Export Normals",
        description="Export vertex normals",
        default=True,
    )
    
    export_tangents: BoolProperty(
        name="Export Tangents",
        description="Export vertex tangents",
        default=True,
    )

    def execute(self, context):
        # Determine which objects to export
        if self.export_selection:
            objects = context.selected_objects
        else:
            objects = context.scene.objects
            
        # Filter for mesh objects only
        mesh_objects = [obj for obj in objects if obj.type == 'MESH']
        
        if not mesh_objects:
            self.report({'ERROR'}, "No mesh objects found to export")
            return {'CANCELLED'}
            
        # Process each mesh object - one file per object
        for obj in mesh_objects:
            try:
                # Generate filename for this mesh
                filepath = self.filepath
                
                # If exporting multiple objects, create individual files
                if len(mesh_objects) > 1:
                    # Get directory and base filename
                    directory = os.path.dirname(filepath)
                    basename = os.path.splitext(os.path.basename(filepath))[0]
                    
                    # Create a new filename with the object name
                    obj_filename = f"{basename}_{obj.name}.mesh"
                    filepath = os.path.join(directory, obj_filename)
                
                # Extract data - includes indices now
                positions, colors, uvs, normals, tangents, indices = extract_mesh_data(obj)
                
                # Convert to engine coordinate system: x=forward, y=left, z=up
                # Blender: -Y=forward, X=right, Z=up
                # So we need: Blender -Y -> Engine X, Blender -X -> Engine Y, Blender Z -> Engine Z
                positions = [self._convert_to_engine_coords(p) for p in positions]
                normals = [self._convert_to_engine_coords(n) for n in normals]
                
                # For tangents, we need to preserve the w component
                new_tangents = []
                for t in tangents:
                    converted = self._convert_to_engine_coords(t[:3])
                    converted.append(t[3])  # Add the w component back
                    new_tangents.append(converted)
                tangents = new_tangents
                
                # Write the mesh data to a binary file
                self._write_binary_mesh_file(filepath, obj.name, positions, colors, uvs, normals, tangents, indices)
                
                self.report({'INFO'}, f"Exported {obj.name} to {filepath}")
                
            except Exception as e:
                self.report({'ERROR'}, f"Error processing object {obj.name}: {str(e)}")
                return {'CANCELLED'}
        
        return {'FINISHED'}
    
    def _convert_to_engine_coords(self, coord):
        """Convert from Blender coordinates to engine coordinates
        Blender: -Y=forward, X=right, Z=up
        Engine: X=forward, Y=left, Z=up
        """
        return [-coord[1], -coord[0], coord[2]]
    
    def _write_binary_mesh_file(self, filepath, obj_name, positions, colors, uvs, normals, tangents, indices):
        """Write mesh data to a binary file with the specified format"""
        with open(filepath, 'wb') as f:
            # Write header
            # 1. Name string length (64-bit int)
            name_bytes = obj_name.encode('utf-8')
            name_length = len(name_bytes)
            f.write(struct.pack('q', name_length))  # Q = 64-bit unsigned long long
            
            # 2. Name characters (UTF-8)
            f.write(name_bytes)
            
            # 3. Num verts (64-bit int)
            num_verts = len(positions)
            f.write(struct.pack('q', num_verts))
            
            # 4. Num indices (64-bit int)
            num_indices = len(indices)
            f.write(struct.pack('q', num_indices))
            
            # Write data section
            # 1. All positions (32-bit floats)
            for pos in positions:
                f.write(struct.pack('fff', pos[0], pos[1], pos[2]))
            
            # 2. All colors (32-bit floats)
            if self.export_colors:
                for color in colors:
                    f.write(struct.pack('ffff', color[0], color[1], color[2], color[3]))
            
            # 3. All tex_coords (32-bit floats)
            if self.export_uvs:
                for uv in uvs:
                    f.write(struct.pack('ff', uv[0], uv[1]))
            
            # 4. All normals (32-bit floats)
            if self.export_normals:
                for normal in normals:
                    f.write(struct.pack('fff', normal[0], normal[1], normal[2]))
            
            # 5. All tangents (32-bit floats)
            if self.export_tangents:
                for tangent in tangents:
                    f.write(struct.pack('ffff', tangent[0], tangent[1], tangent[2], tangent[3]))
            
            # 6. Write indices (32-bit ints)
            for index in indices:
                f.write(struct.pack('I', index))  # I = 32-bit unsigned int


# Only needed if you want to add into a dynamic menu
def menu_func_export(self, context):
    self.layout.operator(ExportMeshData.bl_idname, text="Mesh Data (.mesh)")


def register():
    bpy.utils.register_class(ExportMeshData)
    bpy.types.TOPBAR_MT_file_export.append(menu_func_export)


def unregister():
    bpy.utils.unregister_class(ExportMeshData)
    bpy.types.TOPBAR_MT_file_export.remove(menu_func_export)


if __name__ == "__main__":
    register()