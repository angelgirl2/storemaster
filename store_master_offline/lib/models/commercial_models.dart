// ============================================================================
// Commercial models - امکانات تجاری پیشرفته StoreMaster Pro
// ============================================================================

class FiscalYear {
  final int id;
  final int year;
  final int startMillis;
  final int endMillis;
  final bool isClosed;
  const FiscalYear({this.id=0, required this.year, required this.startMillis, required this.endMillis, this.isClosed=false});
  Map<String,dynamic> toMap()=>{'id':id==0?null:id,'year':year,'startMillis':startMillis,'endMillis':endMillis,'isClosed':isClosed?1:0};
  factory FiscalYear.fromMap(Map<String,dynamic> m)=>FiscalYear(
    id:(m['id'] as num?)?.toInt()??0,
    year:(m['year'] as num?)?.toInt()??0,
    startMillis:(m['startMillis'] as num?)?.toInt()??0,
    endMillis:(m['endMillis'] as num?)?.toInt()??0,
    isClosed:(m['isClosed'] as num? ?? 0)==1,
  );
}

class CheckRecord {
  final int id;
  final String type; // RECEIVED / PAYABLE
  final int? contactId;
  final String contactName;
  final String number;
  final double amount;
  final int dueDateMillis;
  final String bankName;
  final String status; // PENDING / CLEARED / RETURNED / CANCELLED
  final int? cashBankId;
  final int? settlementId;
  final int? clearedDateMillis;
  final String description;
  final int userId;
  final String userName;
  const CheckRecord({this.id=0, required this.type, this.contactId, this.contactName='', required this.number, required this.amount, required this.dueDateMillis, this.bankName='', this.status='PENDING', this.cashBankId, this.settlementId, this.clearedDateMillis, this.description='', this.userId=0, this.userName=''});
  Map<String,dynamic> toMap()=>{'id':id==0?null:id,'type':type,'contactId':contactId,'contactName':contactName,'number':number,'amount':amount,'dueDateMillis':dueDateMillis,'bankName':bankName,'status':status,'cashBankId':cashBankId,'settlementId':settlementId,'clearedDateMillis':clearedDateMillis,'description':description,'userId':userId,'userName':userName};
  factory CheckRecord.fromMap(Map<String,dynamic> m)=>CheckRecord(
    id:(m['id'] as num?)?.toInt()??0,type:(m['type'] as String?)??'RECEIVED',contactId:(m['contactId'] as num?)?.toInt(),contactName:(m['contactName'] as String?)??'',number:(m['number'] as String?)??'',amount:(m['amount'] as num?)?.toDouble()??0,dueDateMillis:(m['dueDateMillis'] as num?)?.toInt()??0,bankName:(m['bankName'] as String?)??'',status:(m['status'] as String?)??'PENDING',cashBankId:(m['cashBankId'] as num?)?.toInt(),settlementId:(m['settlementId'] as num?)?.toInt(),clearedDateMillis:(m['clearedDateMillis'] as num?)?.toInt(),description:(m['description'] as String?)??'',userId:(m['userId'] as num?)?.toInt()??0,userName:(m['userName'] as String?)??''
  );
}

class InstallmentRecord {
  final int id;
  final int transactionId;
  final int? contactId;
  final String contactName;
  final int dueDateMillis;
  final double amount;
  final double paidAmount;
  final String status; // OPEN / PARTIAL / PAID / CANCELLED
  final String description;
  const InstallmentRecord({this.id=0, required this.transactionId, this.contactId, this.contactName='', required this.dueDateMillis, required this.amount, this.paidAmount=0, this.status='OPEN', this.description=''});
  Map<String,dynamic> toMap()=>{'id':id==0?null:id,'transactionId':transactionId,'contactId':contactId,'contactName':contactName,'dueDateMillis':dueDateMillis,'amount':amount,'paidAmount':paidAmount,'status':status,'description':description};
  factory InstallmentRecord.fromMap(Map<String,dynamic> m)=>InstallmentRecord(id:(m['id'] as num?)?.toInt()??0,transactionId:(m['transactionId'] as num?)?.toInt()??0,contactId:(m['contactId'] as num?)?.toInt(),contactName:(m['contactName'] as String?)??'',dueDateMillis:(m['dueDateMillis'] as num?)?.toInt()??0,amount:(m['amount'] as num?)?.toDouble()??0,paidAmount:(m['paidAmount'] as num?)?.toDouble()??0,status:(m['status'] as String?)??'OPEN',description:(m['description'] as String?)??'');
}

class BankReconciliation {
  final int id;
  final int cashBankId;
  final int statementDateMillis;
  final double statementBalance;
  final double bookBalance;
  final double difference;
  final String status; // OPEN / RECONCILED
  final String notes;
  final int userId;
  final String userName;
  const BankReconciliation({this.id=0, required this.cashBankId, required this.statementDateMillis, required this.statementBalance, required this.bookBalance, required this.difference, this.status='OPEN', this.notes='', this.userId=0, this.userName=''});
  Map<String,dynamic> toMap()=>{'id':id==0?null:id,'cashBankId':cashBankId,'statementDateMillis':statementDateMillis,'statementBalance':statementBalance,'bookBalance':bookBalance,'difference':difference,'status':status,'notes':notes,'userId':userId,'userName':userName};
  factory BankReconciliation.fromMap(Map<String,dynamic> m)=>BankReconciliation(id:(m['id'] as num?)?.toInt()??0,cashBankId:(m['cashBankId'] as num?)?.toInt()??0,statementDateMillis:(m['statementDateMillis'] as num?)?.toInt()??0,statementBalance:(m['statementBalance'] as num?)?.toDouble()??0,bookBalance:(m['bookBalance'] as num?)?.toDouble()??0,difference:(m['difference'] as num?)?.toDouble()??0,status:(m['status'] as String?)??'OPEN',notes:(m['notes'] as String?)??'',userId:(m['userId'] as num?)?.toInt()??0,userName:(m['userName'] as String?)??'');
}

class WarehouseRecord {
  final int id;
  final String code;
  final String name;
  final String location;
  final bool isDefault;
  final bool isActive;
  const WarehouseRecord({this.id=0, required this.code, required this.name, this.location='', this.isDefault=false, this.isActive=true});
  Map<String,dynamic> toMap()=>{'id':id==0?null:id,'code':code,'name':name,'location':location,'isDefault':isDefault?1:0,'isActive':isActive?1:0};
  factory WarehouseRecord.fromMap(Map<String,dynamic> m)=>WarehouseRecord(id:(m['id'] as num?)?.toInt()??0,code:(m['code'] as String?)??'',name:(m['name'] as String?)??'',location:(m['location'] as String?)??'',isDefault:(m['isDefault'] as num? ?? 0)==1,isActive:(m['isActive'] as num? ?? 1)==1);
}

class WarehouseStock {
  final int id;
  final int warehouseId;
  final int productId;
  final double quantity;
  const WarehouseStock({this.id=0, required this.warehouseId, required this.productId, this.quantity=0});
  Map<String,dynamic> toMap()=>{'id':id==0?null:id,'warehouseId':warehouseId,'productId':productId,'quantity':quantity};
  factory WarehouseStock.fromMap(Map<String,dynamic> m)=>WarehouseStock(id:(m['id'] as num?)?.toInt()??0,warehouseId:(m['warehouseId'] as num?)?.toInt()??0,productId:(m['productId'] as num?)?.toInt()??0,quantity:(m['quantity'] as num?)?.toDouble()??0);
}

class PriceListRecord {
  final int id;
  final String name;
  final bool isDefault;
  final bool isActive;
  const PriceListRecord({this.id=0, required this.name, this.isDefault=false, this.isActive=true});
  Map<String,dynamic> toMap()=>{'id':id==0?null:id,'name':name,'isDefault':isDefault?1:0,'isActive':isActive?1:0};
  factory PriceListRecord.fromMap(Map<String,dynamic> m)=>PriceListRecord(id:(m['id'] as num?)?.toInt()??0,name:(m['name'] as String?)??'',isDefault:(m['isDefault'] as num? ?? 0)==1,isActive:(m['isActive'] as num? ?? 1)==1);
}

class ProductPriceRecord {
  final int id;
  final int priceListId;
  final int productId;
  final double price;
  const ProductPriceRecord({this.id=0, required this.priceListId, required this.productId, required this.price});
  Map<String,dynamic> toMap()=>{'id':id==0?null:id,'priceListId':priceListId,'productId':productId,'price':price};
  factory ProductPriceRecord.fromMap(Map<String,dynamic> m)=>ProductPriceRecord(id:(m['id'] as num?)?.toInt()??0,priceListId:(m['priceListId'] as num?)?.toInt()??0,productId:(m['productId'] as num?)?.toInt()??0,price:(m['price'] as num?)?.toDouble()??0);
}

class SerialNumberRecord {
  final int id;
  final int productId;
  final String serial;
  final String status; // AVAILABLE / SOLD / RETURNED / RESERVED
  final int? warehouseId;
  final int? transactionId;
  const SerialNumberRecord({this.id=0, required this.productId, required this.serial, this.status='AVAILABLE', this.warehouseId, this.transactionId});
  Map<String,dynamic> toMap()=>{'id':id==0?null:id,'productId':productId,'serial':serial,'status':status,'warehouseId':warehouseId,'transactionId':transactionId};
  factory SerialNumberRecord.fromMap(Map<String,dynamic> m)=>SerialNumberRecord(id:(m['id'] as num?)?.toInt()??0,productId:(m['productId'] as num?)?.toInt()??0,serial:(m['serial'] as String?)??'',status:(m['status'] as String?)??'AVAILABLE',warehouseId:(m['warehouseId'] as num?)?.toInt(),transactionId:(m['transactionId'] as num?)?.toInt());
}

class TaxRuleRecord {
  final int id;
  final String code;
  final String name;
  final double rate;
  final String type;
  final bool isActive;
  const TaxRuleRecord({this.id=0, required this.code, required this.name, required this.rate, this.type='VAT', this.isActive=true});
  Map<String,dynamic> toMap()=>{'id':id==0?null:id,'code':code,'name':name,'rate':rate,'type':type,'isActive':isActive?1:0};
  factory TaxRuleRecord.fromMap(Map<String,dynamic> m)=>TaxRuleRecord(id:(m['id'] as num?)?.toInt()??0,code:(m['code'] as String?)??'',name:(m['name'] as String?)??'',rate:(m['rate'] as num?)?.toDouble()??0,type:(m['type'] as String?)??'VAT',isActive:(m['isActive'] as num? ?? 1)==1);
}

class CostCenterRecord {
  final int id;
  final String code;
  final String name;
  final bool isActive;
  const CostCenterRecord({this.id=0, required this.code, required this.name, this.isActive=true});
  Map<String,dynamic> toMap()=>{'id':id==0?null:id,'code':code,'name':name,'isActive':isActive?1:0};
  factory CostCenterRecord.fromMap(Map<String,dynamic> m)=>CostCenterRecord(id:(m['id'] as num?)?.toInt()??0,code:(m['code'] as String?)??'',name:(m['name'] as String?)??'',isActive:(m['isActive'] as num? ?? 1)==1);
}
