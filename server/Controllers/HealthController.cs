using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using StoreMaster.Server.Data;

namespace StoreMaster.Server.Controllers;

[ApiController]
[Route("health")]
public class HealthController : ControllerBase
{
    private readonly StoreMasterDbContext _db;

    public HealthController(StoreMasterDbContext db) => _db = db;

    [HttpGet]
    public IActionResult Live() => Ok(new
    {
        status = "ok",
        service = "StoreMaster API",
        utc = DateTime.UtcNow
    });

    [HttpGet("ready")]
    public async Task<IActionResult> Ready()
    {
        try
        {
            if (!await _db.Database.CanConnectAsync())
                return StatusCode(503, new { status = "not_ready", database = "unreachable" });

            return Ok(new
            {
                status = "ready",
                database = "ok",
                utc = DateTime.UtcNow
            });
        }
        catch (Exception ex)
        {
            return StatusCode(503, new
            {
                status = "not_ready",
                database = "error",
                error = ex.GetType().Name
            });
        }
    }
}
