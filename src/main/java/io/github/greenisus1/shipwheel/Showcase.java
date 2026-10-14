package io.github.greenisus1.shipwheel;

import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.World;
import org.bukkit.block.Block;
import org.bukkit.block.data.Rotatable;

/** Builds a small demo world: ocean, islands, a road, boats and cars, all with working ship wheels. */
final class Showcase {
    private Showcase() {}

    static void build(ShipWheelPlugin pl, Location origin) {
        World w = origin.getWorld();
        int ox = origin.getBlockX(), oy = origin.getBlockY(), oz = origin.getBlockZ();
        int R = 70;
        // ocean: sand floor, water up to oy-1, air above
        for (int x = -R; x <= R; x++) for (int z = -R; z <= R; z++) {
            for (int y = -8; y <= 12; y++) {
                Material m = y < -6 ? Material.STONE : y == -6 ? Material.SAND : y < 0 ? Material.WATER : Material.AIR;
                set(w, ox + x, oy + y, oz + z, m);
            }
        }
        island(w, ox, oy, oz, 0, 0, 16);
        island(w, ox, oy, oz, 45, 28, 10);
        island(w, ox, oy, oz, -40, -28, 9);
        tree(w, ox + 40, oy, oz + 28);
        tree(w, ox + 49, oy, oz + 30);
        tree(w, ox - 40, oy, oz - 28);
        // road along X on the main island (smooth stone, polished andesite edges)
        for (int x = -14; x <= 14; x++) {
            for (int z = -2; z <= 2; z++) set(w, ox + x, oy - 1, oz + z, (z == -2 || z == 2) ? Material.POLISHED_ANDESITE : Material.SMOOTH_STONE);
        }
        car(pl, w, ox - 10, oy, oz, Material.RED_CONCRETE);
        car(pl, w, ox + 3, oy, oz, Material.BLUE_CONCRETE);
        boat(pl, w, ox + 30, oy, oz - 6);
        boat(pl, w, ox - 28, oy, oz + 14);
        boat(pl, w, ox + 28, oy, oz + 44);
        // small bridge-ish dock to the second island
        for (int z = 12; z <= 20; z++) set(w, ox + 36, oy - 1, oz + z, Material.OAK_PLANKS);
    }

    static void set(World w, int x, int y, int z, Material m) { w.getBlockAt(x, y, z).setType(m, false); }

    static void island(World w, int ox, int oy, int oz, int cx, int cz, int r) {
        for (int x = -r; x <= r; x++) for (int z = -r; z <= r; z++) {
            double d = Math.sqrt(x * x + z * z);
            if (d > r) continue;
            int top = d > r - 3 ? -1 : -1;
            for (int y = -6; y <= top; y++) {
                Material m = y == top ? (d > r - 2 ? Material.SAND : Material.GRASS_BLOCK) : (y > top - 3 ? Material.DIRT : Material.SAND);
                set(w, ox + cx + x, oy + y, oz + cz + z, m);
            }
        }
    }

    static void tree(World w, int x, int oy, int z) {
        for (int y = 0; y < 5; y++) set(w, x, oy + y, z, Material.OAK_LOG);
        for (int dx = -2; dx <= 2; dx++) for (int dz = -2; dz <= 2; dz++) for (int dy = 3; dy <= 5; dy++) {
            if (Math.abs(dx) + Math.abs(dz) + (dy - 3) <= 3 && !(dx == 0 && dz == 0 && dy < 5)) set(w, x + dx, oy + dy, z + dz, Material.OAK_LEAVES);
        }
    }

    static void wheel(ShipWheelPlugin pl, World w, int x, int y, int z) {
        Block b = w.getBlockAt(x, y, z);
        b.setType(Material.BARREL, false);
        pl.markWheel(b);
    }

    // Car: 5 long (x), 3 wide (z). Base at y = oy (wheels), body above.
    static void car(ShipWheelPlugin pl, World w, int x0, int oy, int z0, Material body) {
        for (int dx : new int[]{0, 4}) for (int dz : new int[]{-1, 1}) set(w, x0 + dx, oy, z0 + dz, Material.BLACK_CONCRETE);
        for (int dx = 0; dx <= 4; dx++) for (int dz = -1; dz <= 1; dz++) set(w, x0 + dx, oy + 1, z0 + dz, body);
        // hood and trunk are solid; cabin in the middle
        for (int dz = -1; dz <= 1; dz++) { set(w, x0 + 1, oy + 2, z0 + dz, dz == 0 ? Material.AIR : Material.GLASS); set(w, x0 + 3, oy + 2, z0 + dz, dz == 0 ? Material.AIR : Material.GLASS); }
        set(w, x0 + 1, oy + 2, z0, Material.AIR);
        set(w, x0 + 2, oy + 2, z0 - 1, Material.GLASS); set(w, x0 + 2, oy + 2, z0 + 1, Material.GLASS);
        for (int dz = -1; dz <= 1; dz++) set(w, x0 + 2, oy + 3, z0 + dz, Material.BLACK_CONCRETE);
        for (int dx = 1; dx <= 3; dx++) set(w, x0 + dx, oy + 3, z0, Material.BLACK_CONCRETE);
        for (int dx = 1; dx <= 3; dx++) for (int dz = -1; dz <= 1; dz++) set(w, x0 + dx, oy + 3, z0 + dz, Material.BLACK_CONCRETE);
        set(w, x0 + 4, oy + 2, z0 - 1, Material.YELLOW_CONCRETE); // taillights / headlights
        set(w, x0 + 4, oy + 2, z0 + 1, Material.YELLOW_CONCRETE);
        wheel(pl, w, x0 + 1, oy + 2, z0 - 1 + 1); // ship wheel as the steering wheel
    }

    // Boat: hull 9 long (z), 5 wide (x), floor at y = oy-1 (water surface level), deck rails above.
    static void boat(ShipWheelPlugin pl, World w, int cx, int oy, int z0) {
        for (int dz = 0; dz <= 8; dz++) for (int dx = -2; dx <= 2; dx++) {
            boolean edge = Math.abs(dx) == 2 || dz == 0 || dz == 8;
            if (dz == 8 && Math.abs(dx) == 2) continue; // rounded stern
            set(w, cx + dx, oy - 1, z0 + dz, Material.SPRUCE_PLANKS);
            if (edge) set(w, cx + dx, oy, z0 + dz, Material.OAK_PLANKS);
        }
        set(w, cx, oy, z0, Material.AIR);
        set(w, cx, oy, z0 - 1, Material.AIR);
        // bow point
        set(w, cx, oy - 1, z0 - 1, Material.SPRUCE_PLANKS); set(w, cx, oy, z0 - 1, Material.OAK_PLANKS);
        for (int y = 0; y <= 5; y++) set(w, cx, oy + y, z0 + 3, Material.OAK_LOG);
        for (int dx = -1; dx <= 1; dx++) for (int y = 2; y <= 5; y++) set(w, cx + dx, oy + y, z0 + 4, Material.WHITE_WOOL);
        wheel(pl, w, cx, oy, z0 + 6);
    }
}
