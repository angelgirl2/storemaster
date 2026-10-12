using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Models;

namespace StoreMaster.Server.Data;

public class StoreMasterDbContext : DbContext
{
    public StoreMasterDbContext(DbContextOptions<StoreMasterDbContext> o) : base(o) { }

    public DbSet<Store> Stores => Set<Store>();
    public DbSet<User> Users => Set<User>();
    public DbSet<StoreUser> StoreUsers => Set<StoreUser>();
    public DbSet<License> Licenses => Set<License>();
    public DbSet<DiscountCode> DiscountCodes => Set<DiscountCode>();
    public DbSet<SyncChange> SyncChanges => Set<SyncChange>();
    public DbSet<UserDevice> UserDevices => Set<UserDevice>();
    public DbSet<CloudRecord> CloudRecords => Set<CloudRecord>();
    public DbSet<PricingEntry> PricingEntries => Set<PricingEntry>();
    public DbSet<SupportTicket> SupportTickets => Set<SupportTicket>();
    public DbSet<SupportMessage> SupportMessages => Set<SupportMessage>();
    public DbSet<InvoiceShare> InvoiceShares => Set<InvoiceShare>();
    public DbSet<TrialPolicy> TrialPolicies => Set<TrialPolicy>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<Store>().HasIndex(x => x.Code).IsUnique();
        b.Entity<License>().HasIndex(x => x.LicenseId).IsUnique();
        b.Entity<License>().HasIndex(x => x.ActivationCode).IsUnique();
        b.Entity<DiscountCode>().HasIndex(x => x.Code).IsUnique();
        b.Entity<StoreUser>().HasIndex(x => new { x.StoreId, x.UserId }).IsUnique();
        b.Entity<UserDevice>().HasIndex(x => new { x.StoreId, x.UserId, x.DeviceId }).IsUnique();
        b.Entity<CloudRecord>().HasIndex(x => new { x.StoreId, x.Entity, x.EntityId }).IsUnique();
        b.Entity<PricingEntry>().HasIndex(x => x.PlanDays).IsUnique();
        b.Entity<SupportTicket>().HasIndex(x => x.TicketCode).IsUnique();
        b.Entity<SupportMessage>().HasIndex(x => new { x.TicketId, x.Id });
        b.Entity<InvoiceShare>().HasIndex(x => x.Token).IsUnique();
        b.Entity<InvoiceShare>().HasIndex(x => new { x.StoreId, x.CreatedAt });
    }
}
