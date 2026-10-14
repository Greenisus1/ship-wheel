package io.github.greenisus1.shipwheel;

import org.bukkit.*;
import org.bukkit.attribute.Attribute;
import org.bukkit.block.Block;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.BlockDisplay;
import org.bukkit.entity.Horse;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.util.Transformation;
import org.joml.AxisAngle4f;
import org.joml.Vector3f;

import java.io.File;
import java.util.*;

/**
 * A structure turned into display entities, carried by an invisible saddled horse (jump disabled).
 * While mounted the real blocks are gone; on dismount they are placed again, snapped to the block grid
 * and to the nearest 90 degree turn. A copy of the blocks is saved to disk so a crash cannot lose them.
 */
class EntityVehicle {
    final ShipWheelPlugin pl; final UUID id = UUID.randomUUID();
    final World world; final List<Cell> cells; final int px, py, pz;
    Horse horse; final List<BlockDisplay> displays = new ArrayList<>(); float baseYaw;
    UUID rider;

    EntityVehicle(ShipWheelPlugin pl, Vehicle v) { this.pl = pl; this.world = v.world; this.cells = v.cells; this.px = v.px; this.py = v.py; this.pz = v.pz; }

    File file() { return new File(pl.getDataFolder(), "active-" + id + ".yml"); }

    static EntityVehicle create(ShipWheelPlugin pl, Block wheel, Player rider) {
        Vehicle v = Vehicle.assemble(pl, wheel, ShipWheelPlugin.yawToDir(rider.getLocation().getYaw()));
        if (v == null) return null;
        EntityVehicle ev = new EntityVehicle(pl, v);
        ev.save();
        for (Cell c : ev.cells) ev.world.getBlockAt(ev.px + c.dx(), ev.py + c.dy(), ev.pz + c.dz()).setBlockData(Material.AIR.createBlockData(), false);
        ev.spawn(rider);
        return ev;
    }

    void save() {
        pl.getDataFolder().mkdirs();
        YamlConfiguration y = new YamlConfiguration();
        y.set("world", world.getName()); y.set("px", px); y.set("py", py); y.set("pz", pz);
        List<String> l = new ArrayList<>();
        for (Cell c : cells) l.add(c.dx() + "," + c.dy() + "," + c.dz() + "," + c.data().getAsString());
        y.set("cells", l);
        try { y.save(file()); } catch (Exception e) { pl.getLogger().warning("Could not save vehicle backup: " + e); }
    }

    static void restoreLeftovers(ShipWheelPlugin pl) {
        File[] fs = pl.getDataFolder().listFiles((d, n) -> n.startsWith("active-") && n.endsWith(".yml"));
        if (fs == null) return;
        for (File f : fs) {
            YamlConfiguration y = YamlConfiguration.loadConfiguration(f);
            World w = Bukkit.getWorld(y.getString("world", ""));
            if (w == null) continue;
            int px = y.getInt("px"), py = y.getInt("py"), pz = y.getInt("pz"); int n = 0;
            for (String s : y.getStringList("cells")) {
                String[] p = s.split(",", 4);
                w.getBlockAt(px + Integer.parseInt(p[0]), py + Integer.parseInt(p[1]), pz + Integer.parseInt(p[2])).setBlockData(Bukkit.createBlockData(p[3]), false); n++;
            }
            Block piv = w.getBlockAt(px, py, pz); pl.markWheel(piv);
            f.delete();
            pl.getLogger().info("Restored " + n + " blocks of an unfinished vehicle from " + f.getName());
        }
    }

    void spawn(Player r) {
        rider = r.getUniqueId();
        baseYaw = r.getLocation().getYaw();
        Location at = new Location(world, px + 0.5, py, pz + 0.5, baseYaw, 0);
        horse = world.spawn(at, Horse.class, h -> {
            h.setTamed(true); h.setOwner(r); h.setAdult(); h.setInvisible(true); h.setSilent(true); h.setInvulnerable(true);
            h.setPersistent(false); h.setRemoveWhenFarAway(false);
            h.getInventory().setSaddle(new ItemStack(Material.SADDLE));
            h.getPersistentDataContainer().set(pl.vehicleKey, PersistentDataType.BYTE, (byte) 1);
            var jump = h.getAttribute(Attribute.JUMP_STRENGTH); if (jump != null) jump.setBaseValue(0.0);
            var spd = h.getAttribute(Attribute.MOVEMENT_SPEED); if (spd != null) spd.setBaseValue(0.2);
        });
        for (Cell c : cells) {
            Location l = new Location(world, px + 0.5 + c.dx(), py + c.dy(), pz + 0.5 + c.dz(), 0, 0);
            BlockDisplay d = world.spawn(l, BlockDisplay.class, e -> {
                e.setBlock(c.data()); e.setPersistent(false); e.setTeleportDuration(2);
                e.setTransformation(new Transformation(new Vector3f(-0.5f, 0, -0.5f), new AxisAngle4f(), new Vector3f(1, 1, 1), new AxisAngle4f()));
            });
            displays.add(d);
        }
        horse.addPassenger(r);
    }

    void update() {
        if (horse == null || !horse.isValid()) return;
        float dyaw = horse.getLocation().getYaw() - baseYaw;
        double rad = Math.toRadians(dyaw), cos = Math.cos(rad), sin = Math.sin(rad);
        Location h = horse.getLocation();
        for (int i = 0; i < cells.size(); i++) {
            Cell c = cells.get(i); BlockDisplay d = displays.get(i);
            double nx = c.dx() * cos - c.dz() * sin, nz = c.dx() * sin + c.dz() * cos;
            d.teleport(new Location(world, h.getX() + nx, h.getY() + c.dy(), h.getZ() + nz, dyaw, 0));
        }
    }

    int turns() { return ((Math.round((horse.getLocation().getYaw() - baseYaw) / 90f) % 4) + 4) % 4; }

    List<Cell> turned() {
        List<Cell> cur = cells;
        for (int i = 0, k = turns(); i < k; i++) {
            List<Cell> n = new ArrayList<>();
            for (Cell c : cur) n.add(new Cell(-c.dz(), c.dy(), c.dx(), Vehicle.rot(c.data(), true)));
            cur = n;
        }
        return cur;
    }

    /** Finds a vertical offset (0..4) where the turned structure fits, or null. */
    Object[] fit() {
        List<Cell> t = turned();
        Location h = horse.getLocation();
        int bx = h.getBlockX(), bz = h.getBlockZ(), by = (int) Math.round(h.getY());
        Vehicle probe = new Vehicle(); probe.world = world;
        for (int up = 0; up <= 4; up++) {
            boolean ok = true;
            for (Cell c : t) {
                Block b = world.getBlockAt(bx + c.dx(), by + up + c.dy(), bz + c.dz());
                if (!(b.isEmpty() || b.isLiquid() || b.isPassable())) { ok = false; break; }
            }
            if (ok) return new Object[]{t, bx, by + up, bz};
        }
        return null;
    }

    boolean canSolidify() { return horse == null || fit() != null; }

    /** Puts the blocks back. Returns false if no free spot was found (blocks then go back to the original spot as a last resort). */
    void solidify(Player p) {
        Object[] f = horse != null ? fit() : null;
        List<Cell> t; int bx, by, bz;
        if (f != null) { t = (List<Cell>) f[0]; bx = (int) f[1]; by = (int) f[2]; bz = (int) f[3]; }
        else { t = cells; bx = px; by = py; bz = pz; }
        for (Cell c : t) world.getBlockAt(bx + c.dx(), by + c.dy(), bz + c.dz()).setBlockData(c.data(), false);
        pl.markWheel(world.getBlockAt(bx, by, bz));
        for (BlockDisplay d : displays) d.remove();
        displays.clear();
        if (horse != null) { horse.eject(); horse.remove(); horse = null; }
        file().delete();
        if (p != null && p.isOnline()) {
            Location out = new Location(world, bx + 0.5, by + 1, bz + 0.5, p.getLocation().getYaw(), p.getLocation().getPitch());
            for (int i = 0; i < 6; i++) {
                Block b1 = world.getBlockAt(out), b2 = out.clone().add(0, 1, 0).getBlock();
                if ((b1.isEmpty() || b1.isPassable()) && (b2.isEmpty() || b2.isPassable())) break;
                out.add(0, 1, 0);
            }
            p.teleport(out);
        }
    }
}
