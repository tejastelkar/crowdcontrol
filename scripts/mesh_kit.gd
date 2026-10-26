class_name MeshKit
extends RefCounted
## Builds low-poly models by merging primitive shapes into one vertex-coloured mesh.
## One mesh means one draw call, which keeps crowds and scenery cheap on phones.


## parts: Array of [PrimitiveMesh, Transform3D, Color]
static func merge(parts: Array, scale := 1.0) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for part in parts:
		var pm: PrimitiveMesh = part[0]
		var xf: Transform3D = part[1]
		var col: Color = part[2]
		var arr := pm.get_mesh_arrays()
		var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var pi: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var offset := verts.size()
		var nb := xf.basis.inverse().transposed()
		for i in pv.size():
			verts.push_back((xf * pv[i]) * scale)
			norms.push_back((nb * pn[i]).normalized())
			cols.push_back(col)
		for i in pi:
			idx.push_back(i + offset)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func xf(pos: Vector3, scale := Vector3.ONE, rot_deg := Vector3.ZERO) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scale)
	return Transform3D(b, pos)


static func sphere(r: float, seg := 10, rings := 6) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = rings
	return m


static func capsule(r: float, h: float, seg := 10, rings := 3) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = seg
	m.rings = rings
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cylinder(top: float, bottom: float, h: float, seg := 12) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m


## Lit material that takes its colour from the mesh's vertex colours.
static func vertex_material(roughness := 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = roughness
	return m


static func color_material(c: Color, roughness := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	return m


static func instance(mesh: Mesh, mat: Material, parent: Node3D, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
