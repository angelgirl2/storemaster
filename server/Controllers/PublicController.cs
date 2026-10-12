using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;

namespace StoreMaster.Server.Controllers;

[ApiController]
[Route("api/v1/public")]
public class PublicController : ControllerBase
{
    readonly StoreMasterDbContext db;

    public PublicController(StoreMasterDbContext db) => this.db = db;

    [HttpGet("time")]
    public IActionResult Time() => Ok(new { serverTime = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds(), utc = DateTime.UtcNow });

    [HttpGet("pricing")]
    public async Task<IActionResult> Pricing()
    {
        var rows = await db.PricingEntries
            .AsNoTracking()
            .OrderBy(x => x.PlanDays)
            .ToListAsync();

        if (rows.Count == 0)
        {
            rows = new List<StoreMaster.Server.Models.PricingEntry>
            {
                new() { PlanDays = 30, Price = 990000, Currency = "تومان" },
                new() { PlanDays = 90, Price = 2490000, Currency = "تومان" },
                new() { PlanDays = 180, Price = 4490000, Currency = "تومان" },
                new() { PlanDays = 365, Price = 7990000, Currency = "تومان" },
            };
        }

        return Ok(new
        {
            version = rows.Max(x => new DateTimeOffset(x.UpdatedAt).ToUnixTimeMilliseconds()),
            currency = rows.FirstOrDefault()?.Currency ?? "تومان",
            prices = rows.ToDictionary(x => x.PlanDays.ToString(), x => x.Price)
        });
    }
}
