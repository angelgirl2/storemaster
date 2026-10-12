namespace StoreMaster.Server.Models;

public class Store
{
    public int Id { get; set; }
    public string Code { get; set; } = "";
    public string Name { get; set; } = "";
    public string Type { get; set; } = "";
    public string BusinessTitle { get; set; } = "";
    public string Currency { get; set; } = "IRR";
    public bool Active { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class User
{
    public int Id { get; set; }
    public string Username { get; set; } = "admin";
    public string Name { get; set; } = "";
    public string Phone { get; set; } = "";
    public string PinHash { get; set; } = "";
    public bool Active { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class StoreUser
{
    public int Id { get; set; }
    public int StoreId { get; set; }
    public int UserId { get; set; }
    public string Role { get; set; } = "SELLER";
    public string PermissionsJson { get; set; } = "[]";
    public bool Active { get; set; } = true;
}

public class UserDevice
{
    public long Id { get; set; }
    public int StoreId { get; set; }
    public int UserId { get; set; }
    public string DeviceId { get; set; } = "";
    public string Platform { get; set; } = "";
    public string Name { get; set; } = "";
    public DateTime FirstSeenAt { get; set; } = DateTime.UtcNow;
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;
    public bool Active { get; set; } = true;
}

public class CloudRecord
{
    public long Id { get; set; }
    public int StoreId { get; set; }
    public string Entity { get; set; } = "";
    public string EntityId { get; set; } = "";
    public string Operation { get; set; } = "UPSERT";
    public string PayloadJson { get; set; } = "{}";
    public long SourceVersion { get; set; }
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    public int UserId { get; set; }
}

public class License
{
    public int Id { get; set; }
    public int StoreId { get; set; }
    public string LicenseId { get; set; } = "";
    public string ActivationCode { get; set; } = "";
    public bool ActivationCodeUsed { get; set; }
    public string Plan { get; set; } = "TRIAL";
    public string Status { get; set; } = "ACTIVE";
    public DateTime IssuedAt { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAt { get; set; }
    public decimal OriginalPrice { get; set; }
    public decimal FinalPrice { get; set; }
    public string DiscountCode { get; set; } = "";
    public string FeaturesJson { get; set; } = "[]";
    public string BusinessTypesJson { get; set; } = "[\"*\"]";
    public int MaxUsers { get; set; } = 5;
    public string Username { get; set; } = "admin";
    // Stored to support one-time online activation-code provisioning.
    // Keep the database secured and never expose this through general admin lists.
    public string InitialPassword { get; set; } = "";
    public string RecoveryCode { get; set; } = "";
}

public class DiscountCode
{
    public int Id { get; set; }
    public string Code { get; set; } = "";
    public int Percent { get; set; }
    public decimal FixedAmount { get; set; }
    public int MaxUses { get; set; }
    public int UsedCount { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public bool Active { get; set; } = true;
}

public class SyncChange
{
    public long Id { get; set; }
    public int StoreId { get; set; }
    public int UserId { get; set; }
    public string Entity { get; set; } = "";
    public string Operation { get; set; } = "UPSERT";
    public string EntityId { get; set; } = "";
    public string PayloadJson { get; set; } = "{}";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class PricingEntry
{
    public int Id { get; set; }
    public int PlanDays { get; set; }
    public decimal Price { get; set; }
    public string Currency { get; set; } = "تومان";
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}


public class TrialPolicy
{
    public int Id { get; set; } = 1;
    public string FeaturesJson { get; set; } = "[\"sales\",\"customers\",\"products\"]";
    public string BusinessTypesJson { get; set; } = "[\"*\"]";
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}

public class SupportTicket
{
    public long Id { get; set; }
    public string TicketCode { get; set; } = "";
    public string Type { get; set; } = "SUPPORT";
    public string StoreCode { get; set; } = "";
    public string LicenseId { get; set; } = "";
    public string Username { get; set; } = "admin";
    public string DeviceId { get; set; } = "";
    public string Contact { get; set; } = "";
    public string Message { get; set; } = "";
    public string Status { get; set; } = "OPEN";
    // SHA-256 hash of a per-ticket client capability token; raw token is returned once.
    public string AccessTokenHash { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class SupportMessage
{
    public long Id { get; set; }
    public long TicketId { get; set; }
    public string SenderRole { get; set; } = "CUSTOMER";
    public string SenderName { get; set; } = "کاربر";
    public string Message { get; set; } = "";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public class InvoiceShare
{
    public long Id { get; set; }
    public string Token { get; set; } = "";
    public int StoreId { get; set; }
    public string StoreName { get; set; } = "";
    public string StorePhone { get; set; } = "";
    public string InvoiceNumber { get; set; } = "";
    public string DateText { get; set; } = "";
    public string CustomerName { get; set; } = "";
    public string Currency { get; set; } = "تومان";
    public string ItemsJson { get; set; } = "[]";
    public decimal TotalAmount { get; set; }
    public decimal Discount { get; set; }
    public decimal FinalAmount { get; set; }
    public decimal PaidAmount { get; set; }
    public decimal DebtAmount { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime ExpiresAt { get; set; }
}
