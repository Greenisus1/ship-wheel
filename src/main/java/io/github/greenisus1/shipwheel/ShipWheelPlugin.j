package io.github.greenisus1.shipwheel;

import net.kyori.adventure.text.Component;
import net.kyori.adventure.text.format.NamedTextColor;
import org.bukkit.*;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.block.BlockState;
import org.bukkit.block.TileState;
import org.bukkit.command.*;
import org.bukkit.entity.Entity;
import org.bukkit.entity.Player;
import org.bukkit.event.*;
import org.bukkit.event.block.*;
import org.bukkit.event.entity.*;
import org.bukkit.event.player.*;
import org.bukkit.inventory.*;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.plugin.java.JavaPlugin;
import org.bukkit.scheduler.BukkitRunnable;

import java.util.*;

/**
 * ShipWheel: place a ship wheel on a structure and right-click it. The structure becomes display entities
 * carried by an invisible horse you ride (no jumping). Dismount and it turns back into solid blocks.
 */
public class ShipWheelPlugin extends JavaPlugin implements Listener {
    NamespacedKey wheelKey, vehicleKey;
    final Map<UUID, EntityVehicle> byRider = new HashMap<>();

    static String key(Location l) { return l.getWorld().getName() + "," + l.getBlockX() + "," + l.getBlockY() + "," + l.getBlockZ(); }

    @Override public void onEnable() {
        wheelKey = new NamespacedKey(this, "ship_wheel");
        vehicleKey = new NamespacedKey(this, "ship_vehicle");
        Bukkit.getPluginManager().registerEvents(this, this);
        ShapedRecipe r = new ShapedRecipe(new NamespacedKey(this, "ship_wheel_recipe"), wheelItem());
        r.shape("SSS", "SPS", "SSS");
        r.setIngredient('S', Material.STICK);
        r.setIngredient('P', Material.DARK_OAK_PLANKS);
        Bukkit.addRecipe(r);
        // blocks of a vehicle that was mounted during a crash come back first
        Bukkit.getScheduler().runTask(this, () -> EntityVehicle.restoreLeftovers(this));
        new BukkitRunnable() { public void run() { tick(); } }.runTaskTimer(this, 1, 1);
    }

    @Override public void onDisable() {
        for (EntityVehicle v : new ArrayList<>(byRider.values())) v.solidify(Bukkit.getPlayer(v.rider));
        byRider.clear();
    }

    void tick() {
        for (var en : new ArrayList<>(byRider.entrySet())) {
            EntityVehicle v = en.getValue();
            if (v.horse == null || !v.horse.isValid()) { v.solidify(Bukkit.getPlayer(en.getKey())); byRider.remove(en.getKey()); continue; }
            v.update();
        }
    }

    void markWheel(Block b) {
        if (b.getType() != Material.BARREL) return;
        BlockState st = b.getState();
        if (st instanceof TileState ts) { ts.getPersistentDataContainer().set(wheelKey, PersistentDataType.BYTE, (byte) 1); ts.update(true, false); }
    }

    boolean isWheel(Block b) {
        if (b.getType() != Material.BARREL) return false;
        return b.getState(false) instanceof TileState ts && ts.getPersistentDataContainer().has(wheelKey, PersistentDataType.BYTE);
    }

    ItemStack wheelItem() {
        ItemStack it = new ItemStack(Material.BARREL);
        var m = it.getItemMeta();
        m.displayName(Component.text("Ship Wheel", NamedTextColor.GOLD));
        m.lore(List.of(Component.text("Place on a build, right-click, ride it like a horse.", NamedTextColor.GRAY),
                Component.text("Sneak to get off and turn it back into blocks.", NamedTextColor.GRAY)));
        m.getPersistentDataContainer().set(wheelKey, PersistentDataType.BYTE, (byte) 1);
        it.setItemMeta(m);
        return it;
    }

    boolean isWheelItem(ItemStack it) {
        return it != null && it.hasItemMeta() && it.getItemMeta().getPersistentDataContainer().has(wheelKey, PersistentDataType.BYTE);
    }

    boolean isVehicleHorse(Entity e) { return e.getPersistentDataContainer().has(vehicleKey, PersistentDataType.BYTE); }

    @Override public boolean onCommand(CommandSender s, Command c, String l, String[] a) {
        if (a.length >= 1 && a[0].equalsIgnoreCase("give")) {
            if (!s.hasPermission("shipwheel.give")) { s.sendMessage("No permission."); return true; }
            Player t = a.length > 1 ? Bukkit.getPlayerExact(a[1]) : (s instanceof Player p ? p : null);
            if (t == null) { s.sendMessage("Player not found."); return true; }
            t.getInventory().addItem(wheelItem());
            s.sendMessage("Gave a Ship Wheel to " + t.getName());
            return true;
        }
        if (a.length >= 1 && a[0].equalsIgnoreCase("showcase") && s.hasPermission("shipwheel.give")) {
            Location at = s instanceof Player pl ? pl.getLocation().getBlock().getLocation() : Bukkit.getWorlds().get(0).getSpawnLocation().getBlock().getLocation();
            s.sendMessage("Building showcase (this can take a few seconds)...");
            Showcase.build(this, at);
            s.sendMessage("Done. Right-click a boat's or car's barrel wheel to ride it.");
            return true;
        }
        if (a.length >= 1 && a[0].equalsIgnoreCase("selftest") && s.hasPermission("shipwheel.give")) {
            selftest();
            return true;
        }
        s.sendMessage("Usage: /shipwheel give [player] | /shipwheel showcase");
        return true;
    }

    /** Console test without a player: turn each wheel's structure into entities, move the horse, turn it back, compare. */
    void selftest() {
        World wd = Bukkit.getWorlds().get(0);
        List<Block> found = new ArrayList<>();
        for (int x = -75; x <= 75; x++) for (int z = -75; z <= 75; z++) for (int y = -64; y <= 20; y++) {
            Block cand = wd.getBlockAt(x, y, z);
            if (cand.getType() == Material.BARREL && isWheel(cand)) found.add(cand);
        }
        for (Block wb : found) {
            Vehicle v = Vehicle.assemble(this, wb, BlockFace.SOUTH);
            if (v == null) continue;
            int n = v.cells.size();
            EntityVehicle ev = new EntityVehicle(this, v);
            ev.save();
            for (Cell c : ev.cells) wd.getBlockAt(ev.px + c.dx(), ev.py + c.dy(), ev.pz + c.dz()).setBlockData(Material.AIR.createBlockData(), false);
            Location at = new Location(wd, ev.px + 0.5, ev.py, ev.pz + 0.5, 0, 0);
            ev.horse = wd.spawn(at, org.bukkit.entity.Horse.class, h -> { h.setInvisible(true); h.setPersistent(false); });
            ev.baseYaw = 0;
            for (Cell c : ev.cells) {
                var d = wd.spawn(new Location(wd, ev.px + 0.5 + c.dx(), ev.py + c.dy(), ev.pz + 0.5 + c.dz()), org.bukkit.entity.BlockDisplay.class, e -> { e.setBlock(c.data()); e.setPersistent(false); });
                ev.displays.add(d);
            }
            ev.horse.teleport(new Location(wd, ev.px + 0.5 + 5, ev.py, ev.pz + 0.5 + 2, 90, 0));
            ev.update();
            boolean fits = ev.canSolidify();
            int start = ev.displays.size();
            ev.solidify(null);
            Vehicle again = Vehicle.assemble(this, wd.getBlockAt(ev.px + 5, ev.py, ev.pz + 2), BlockFace.SOUTH);
            boolean oldGone = !isWheel(wb) || (ev.px + 5 == wb.getX() && ev.pz + 2 == wb.getZ());
            getLogger().info("SELFTEST2 wheel=" + key(wb.getLocation()) + " blocks=" + n + " displays=" + start + " fitted=" + fits
                    + " reassembledAtNewSpot=" + (again == null ? -1 : again.cells.size()) + " oldWheelGone=" + oldGone + " backupFileDeleted=" + !ev.file().exists());
        }
    }

    @EventHandler public void onPlace(BlockPlaceEvent e) {
        if (isWheelItem(e.getItemInHand())) markWheel(e.getBlockPlaced());
    }

    @EventHandler public void onBreak(BlockBreakEvent e) {
        if (isWheel(e.getBlock())) {
            e.setDropItems(false);
            e.getBlock().getWorld().dropItemNaturally(e.getBlock().getLocation(), wheelItem());
        }
    }

    @EventHandler public void onInteract(PlayerInteractEvent e) {
        if (e.getAction() != Action.RIGHT_CLICK_BLOCK || e.getHand() != EquipmentSlot.HAND) return;
        Block b = e.getClickedBlock();
        if (b == null || !isWheel(b)) return;
        e.setCancelled(true);
        Player p = e.getPlayer();
        if (!p.hasPermission("shipwheel.use") || byRider.containsKey(p.getUniqueId()) || p.isInsideVehicle()) return;
        EntityVehicle v = EntityVehicle.create(this, b, p);
        if (v == null) { p.sendActionBar(Component.text("Nothing is attached to this wheel.", NamedTextColor.RED)); return; }
        byRider.put(p.getUniqueId(), v);
        p.sendActionBar(Component.text("Riding " + v.cells.size() + " blocks. Move like a horse, sneak to get off.", NamedTextColor.GREEN));
    }

    @EventHandler public void onDismount(EntityDismountEvent e) {
        if (!(e.getEntity() instanceof Player p) || !isVehicleHorse(e.getDismounted())) return;
        EntityVehicle v = byRider.get(p.getUniqueId());
        if (v == null) return;
        if (!v.canSolidify()) {
            e.setCancelled(true);
            p.sendActionBar(Component.text("No room to land here. Move to open space and sneak again.", NamedTextColor.RED));
            return;
        }
        byRider.remove(p.getUniqueId());
        Bukkit.getScheduler().runTask(this, () -> v.solidify(p));
    }

    @EventHandler public void onMount(EntityMountEvent e) {
        if (isVehicleHorse(e.getMount()) && !(e.getEntity() instanceof Player p && byRider.containsKey(p.getUniqueId()))) e.setCancelled(true);
    }

    @EventHandler public void onClickHorse(PlayerInteractEntityEvent e) {
        if (isVehicleHorse(e.getRightClicked())) e.setCancelled(true);
    }

    @EventHandler public void onQuit(PlayerQuitEvent e) {
        EntityVehicle v = byRider.remove(e.getPlayer().getUniqueId());
        if (v != null) v.solidify(e.getPlayer());
    }

    static BlockFace yawToDir(float yaw) {
        yaw = (yaw % 360 + 360) % 360;
        if (yaw >= 315 || yaw < 45) return BlockFace.SOUTH;
        if (yaw < 135) return BlockFace.WEST;
        if (yaw < 225) return BlockFace.NORTH;
        return BlockFace.EAST;
    }
}
