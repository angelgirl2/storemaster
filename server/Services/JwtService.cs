using Microsoft.IdentityModel.Tokens; using StoreMaster.Server.Models; using System.IdentityModel.Tokens.Jwt; using System.Security.Claims; using System.Text;
namespace StoreMaster.Server.Services;
public class JwtService
{
    private readonly IConfiguration c;
    public JwtService(IConfiguration c)=>this.c=c;
    public string Create(User u, StoreUser su, Store store, IEnumerable<string> permissions, IEnumerable<string> features, DateTime exp)
    {
        var claims=new List<Claim>{
            new(JwtRegisteredClaimNames.Sub,u.Id.ToString()),
            new("storeId",su.StoreId.ToString()),
            new("storeCode",store.Code),
            new(ClaimTypes.Name,u.Name),
            new(ClaimTypes.Role,su.Role)};
        claims.AddRange(permissions.Select(x=>new Claim("perm",x)));
        claims.AddRange(features.Select(x=>new Claim("feature",x)));
        var key=new SymmetricSecurityKey(Encoding.UTF8.GetBytes(c["Jwt:Key"]!));
        var tok=new JwtSecurityToken(c["Jwt:Issuer"],c["Jwt:Audience"],claims,expires:exp,signingCredentials:new SigningCredentials(key,SecurityAlgorithms.HmacSha256));
        return new JwtSecurityTokenHandler().WriteToken(tok);
    }
}
