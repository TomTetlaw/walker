
Bounding_Box :: struct {
    min, max: Vec3;
}

grow_bounding_box :: (box: *Bounding_Box, position: Vec3) {
    box.min = min(box.min, position);
    box.max = max(box.max, position);
}

bounding_box_area :: (box: Bounding_Box) -> float {
    e := box.max - box.min;
    return e.x * e.y + e.y * e.z + e.z * e.x;
}

Triangle :: struct {
    p0, p1, p2: Vec3;
}

Ray :: struct {
    origin: Vec3;
    direction: Vec3;
}

ray_intersects_box :: (box: Bounding_Box, ray: Ray) -> bool {
    inv_dir := v3(1.0) / ray.direction;

    t1 := (box.min.x - ray.origin.x) * inv_dir.x;
    t2 := (box.max.x - ray.origin.x) * inv_dir.x;

    t_min := min(t1, t2);
    t_max := max(t1, t2);

    for 0..1 {
        t1 = (box.min[it] - ray.origin[it]) * inv_dir[it];
        t1 = (box.max[it] - ray.origin[it]) * inv_dir[it];

        t_min = max(t_min, min(t1, t2));
        t_max = min(t_max, max(t1, t2));
    }

    return t_max > max(t_min, 0.0);
}

BVH_Node :: struct {
    bounds: Bounding_Box;
    tri_count: int;
    left_or_first_tri: int;
}

BVH :: struct {
    nodes: [] BVH_Node;
    tri_index: [] int;
    triangles: [] Triangle;
    nodes_used: int;
}

build_bvh :: (arena: *Arena, triangles: [] Triangle) -> BVH {
    profile_scope("build_bvh");

    result: BVH;

    result.nodes = push_view(arena, BVH_Node, triangles.count * 2 - 1);
    result.triangles = triangles;
    result.tri_index = push_view(arena, int, triangles.count);
    for * result.tri_index {
        it.* = xx it_index;
    }

    result.nodes[0].left_or_first_tri = 0;
    result.nodes[0].tri_count = xx triangles.count;

    update_bounds(*result, 0);
    subdivide(*result, 0);

    result.nodes.count = result.nodes_used + 1;
    return result;
}

query_bvh :: (bvh: *BVH, ray: Ray) -> [] Triangle {
    triangles := tarray(Triangle);

    query_nodes(bvh, *triangles, ray, 0);

    return triangles;
}

draw_bvh :: (bvh: *BVH, camera: *Camera_Base) {
    for bvh.nodes {
        mid := (it.bounds.min + it.bounds.max) * .5;
        if distance(mid, camera.position) <= 500 {
            if it.tri_count > 0 {
                debug_draw_bounds(it.bounds, colour_green);
            } else {
                debug_draw_bounds(it.bounds, colour_red);
            }
        }
    }
}

#scope_file

query_nodes :: (bvh: *BVH, triangles: *[..] Triangle, ray: Ray, index: int) {
    node := *bvh.nodes[index];

    if !ray_intersects_box(node.bounds, ray) return;

    if node.tri_count == 0 {
        query_nodes(bvh, triangles, ray, node.left_or_first_tri);
        query_nodes(bvh, triangles, ray, node.left_or_first_tri + 1);
    } else {
        for 0..node.tri_count-1 {
            tri := bvh.triangles[bvh.tri_index[node.left_or_first_tri + it]];
            array_add(triangles, tri);
        }
    }
}

subdivide :: (bvh: *BVH, index: int, depth := 0) {
    node := *bvh.nodes[index];

    if node.tri_count <= 2 {
        return;
    }

    axis := depth % 2;
    mid := (node.bounds.min + node.bounds.max) * .5;
    split_pos := mid[axis];

    i := node.left_or_first_tri;
    j := i + node.tri_count - 1;
    while i <= j {
        tri := bvh.triangles[bvh.tri_index[i]];
        centroid := (tri.p0[axis] + tri.p1[axis] + tri.p2[axis]) / 3.0;

        if centroid < split_pos {
            i += 1;
        } else {
            bvh.tri_index[i], bvh.tri_index[j] = bvh.tri_index[j], bvh.tri_index[i];
            j -= 1;
        }
    }

    left_count := i - node.left_or_first_tri;

    if left_count == 0 || left_count == node.tri_count {
        print("Failed: axis=%, split_pos=%, left_count=%\n", axis, split_pos, left_count);
        return;
    }

    right_count := node.tri_count - left_count;
    left_index := bvh.nodes_used + 1;
    right_index := bvh.nodes_used + 2;
    bvh.nodes_used += 2;

    left_node := *bvh.nodes[left_index];
    left_node.left_or_first_tri = node.left_or_first_tri;
    left_node.tri_count = left_count;

    update_bounds(bvh, left_index);
    subdivide(bvh, left_index, depth + 1);

    right_node := *bvh.nodes[right_index];
    right_node.left_or_first_tri = i;
    right_node.tri_count = right_count;

    update_bounds(bvh, right_index);
    subdivide(bvh, right_index, depth + 1);

    node.left_or_first_tri = xx left_index;
    node.tri_count = 0;
}

update_bounds :: (bvh: *BVH, index: int) {
    node := *bvh.nodes[index];

    box: Bounding_Box;
    box.min = v3(FLOAT32_MAX);
    box.max = v3(-FLOAT32_MAX);

    for 0..node.tri_count-1 {
        tri := bvh.triangles[bvh.tri_index[node.left_or_first_tri + it]];
        box.min = min(box.min, min(min(tri.p0, tri.p1), tri.p2));
        box.max = max(box.max, max(max(tri.p0, tri.p1), tri.p2));
    }

    node.bounds = box;
}