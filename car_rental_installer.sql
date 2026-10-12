-- ตั้งค่าที่ SQL Server ต้องใช้กับ filtered unique index
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON; SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON; SET NUMERIC_ROUNDABORT OFF;
-- ติดตั้งระบบเช่ารถ 7 ตาราง รูปแบบเดียวกับ instnwnd.sql ใช้ GO แบ่งชุดคำสั่ง
-- ลบฐานข้อมูล car_rental_mini_project เดิมและลงใหม่ตามที่ผู้ใช้ร้องขอ
-- หากต้องการให้หยุดเมื่อมีฐานข้อมูลเดิม ให้เปลี่ยน @ResetDatabase เป็น 0
USE master;
SET NOCOUNT ON;
DECLARE @ResetDatabase bit=1;
IF DB_ID(N'car_rental_mini_project') IS NOT NULL
BEGIN
 IF @ResetDatabase<>1 THROW 51200,N'ฐานข้อมูลมีอยู่แล้ว ถ้าต้องการลบและติดตั้งใหม่ เปลี่ยน @ResetDatabase เป็น 1',1;
 EXEC(N'ALTER DATABASE car_rental_mini_project SET SINGLE_USER WITH ROLLBACK IMMEDIATE');
 EXEC(N'DROP DATABASE car_rental_mini_project');
END;
GO
CREATE DATABASE car_rental_mini_project COLLATE Thai_CI_AS;
GO
USE car_rental_mini_project; SET XACT_ABORT ON; BEGIN TRANSACTION;
-- ตาราง customer: ลูกค้า (คัสตอเมอร์)
CREATE TABLE dbo.customer (
    [customer_id] int IDENTITY(1,1) PRIMARY KEY, -- รหัสลูกค้า
    [full_name] nvarchar(200) NOT NULL, -- ชื่อและนามสกุล
    [birth_date] date NOT NULL, -- วันเกิด ใช้ตรวจอายุขั้นต่ำ 20 ปี
    [identity_document_no] nvarchar(50) NOT NULL, -- เลขบัตรประชาชนหรือพาสปอร์ต
    [license_no] nvarchar(50) NOT NULL, -- เลขใบขับขี่
    [license_expiry_date] date NOT NULL, -- วันหมดอายุใบขับขี่
    [phone] nvarchar(20) NOT NULL, -- เบอร์โทรศัพท์
    [email] nvarchar(150) NULL, -- อีเมล
    [address] nvarchar(300) NULL, -- ที่อยู่
    [status] varchar(20) NOT NULL, -- สถานะ ACTIVE / SUSPENDED
    UNIQUE(identity_document_no),
    UNIQUE(license_no),
    CHECK(status IN ('ACTIVE','SUSPENDED')),
    CHECK(license_expiry_date >= birth_date)
);
-- ตาราง vehicle: รถยนต์ (วีฮิเคิล)
CREATE TABLE dbo.vehicle (
    [vehicle_id] int IDENTITY(1,1) PRIMARY KEY, -- รหัสรถ
    [registration_no] nvarchar(20) NOT NULL, -- หมายเลขทะเบียนรถ
    [registration_province] nvarchar(100) NOT NULL, -- จังหวัดทะเบียนรถ
    [brand] nvarchar(50) NOT NULL, -- ยี่ห้อรถ
    [model] nvarchar(100) NOT NULL, -- รุ่นรถ
    [vehicle_type] nvarchar(50) NOT NULL, -- ประเภทรถ เช่น เก๋ง SUV รถตู้
    [model_year] smallint NOT NULL, -- ปีรถ ค.ศ.
    [daily_rate] decimal(12,2) NOT NULL, -- อัตราค่าเช่าต่อวัน
    [deposit_amount] decimal(12,2) NOT NULL, -- เงินประกันที่ต้องวาง
    [current_mileage] int NOT NULL, -- เลขไมล์ล่าสุด
    [status] varchar(20) NOT NULL, -- สถานะ AVAILABLE / RESERVED / RENTED / MAINTENANCE
    UNIQUE(registration_no,registration_province),
    CHECK(daily_rate>0 AND deposit_amount>=0 AND current_mileage>=0),
    CHECK(model_year BETWEEN 1900 AND 2200),
    CHECK(status IN ('AVAILABLE','RESERVED','RENTED','MAINTENANCE'))
);
-- ตาราง employee: พนักงาน (เอ็มพลอยอี)
CREATE TABLE dbo.employee (
    [employee_id] int IDENTITY(1,1) PRIMARY KEY, -- รหัสพนักงาน
    [employee_code] varchar(20) NOT NULL, -- รหัสพนักงานที่ใช้ในองค์กร
    [full_name] nvarchar(200) NOT NULL, -- ชื่อและนามสกุล
    [phone] nvarchar(20) NOT NULL, -- เบอร์โทรศัพท์
    [role] varchar(20) NOT NULL, -- บทบาท STAFF / MANAGER
    [status] varchar(20) NOT NULL, -- สถานะ ACTIVE / INACTIVE
    UNIQUE(employee_code),
    CHECK(role IN ('STAFF','MANAGER')),
    CHECK(status IN ('ACTIVE','INACTIVE'))
);
-- ตาราง reservation: การจอง (เรเซอร์เวชัน)
CREATE TABLE dbo.reservation (
    [reservation_id] int IDENTITY(1,1) PRIMARY KEY, -- รหัสการจอง
    [reservation_no] varchar(30) NOT NULL, -- เลขที่การจอง
    [customer_id] int NOT NULL REFERENCES dbo.customer(customer_id), -- ลูกค้าที่จอง
    [vehicle_id] int NOT NULL REFERENCES dbo.vehicle(vehicle_id), -- รถเฉพาะคันที่จอง
    [reserved_at] datetime2(0) NOT NULL, -- วันเวลาทำการจอง
    [pickup_at] datetime2(0) NOT NULL, -- วันเวลานัดรับรถ
    [return_at] datetime2(0) NOT NULL, -- วันเวลานัดคืนรถ ต้องหลัง pickup_at
    [expires_at] datetime2(0) NOT NULL, -- วันเวลาหมดอายุการจอง
    [status] varchar(20) NOT NULL, -- PENDING / CONFIRMED / CANCELLED / CONVERTED / EXPIRED
    [cancelled_at] datetime2(0) NULL, -- วันเวลายกเลิก
    [cancellation_reason] nvarchar(300) NULL, -- เหตุผลยกเลิก
    UNIQUE(reservation_no),
    CHECK(return_at>pickup_at),
    CHECK(expires_at>=reserved_at),
    CHECK(status IN ('PENDING','CONFIRMED','CANCELLED','CONVERTED','EXPIRED')),
    CHECK((status='CANCELLED' AND cancelled_at IS NOT NULL AND cancellation_reason IS NOT NULL) OR (status<>'CANCELLED' AND cancelled_at IS NULL))
);
-- ตาราง rental: สัญญาเช่า (เรนทัล)
CREATE TABLE dbo.rental (
    [rental_id] int IDENTITY(1,1) PRIMARY KEY, -- รหัสสัญญาเช่า
    [rental_no] varchar(30) NOT NULL, -- เลขที่สัญญา
    [reservation_id] int NULL REFERENCES dbo.reservation(reservation_id), -- การจองต้นทาง เว้นว่างเมื่อเช่าโดยตรง
    [customer_id] int NOT NULL REFERENCES dbo.customer(customer_id), -- ลูกค้าผู้เช่า
    [vehicle_id] int NOT NULL REFERENCES dbo.vehicle(vehicle_id), -- รถที่เช่า
    [pickup_employee_id] int NOT NULL REFERENCES dbo.employee(employee_id), -- พนักงานส่งมอบรถ
    [return_employee_id] int NULL REFERENCES dbo.employee(employee_id), -- พนักงานรับคืน ยังว่างได้ก่อนคืนรถ
    [pickup_at] datetime2(0) NOT NULL, -- วันเวลาเริ่มเช่าตามสัญญา
    [due_return_at] datetime2(0) NOT NULL, -- วันเวลากำหนดคืน
    [actual_pickup_at] datetime2(0) NULL, -- วันเวลาส่งมอบจริง
    [actual_return_at] datetime2(0) NULL, -- วันเวลาคืนจริง
    [agreed_daily_rate] decimal(12,2) NOT NULL, -- อัตราค่าเช่าที่ตกลงไว้ ณ วันทำสัญญา
    [insurance_selected] bit NOT NULL, -- เลือกซื้อประกัน 1=ซื้อ 0=ไม่ซื้อ
    [insurance_fee] decimal(12,2) NOT NULL, -- ค่าประกันตามสัญญา
    [deductible_amount] decimal(12,2) NOT NULL, -- ค่าเสียหายส่วนแรกตามเงื่อนไขประกัน
    [required_deposit] decimal(12,2) NOT NULL, -- เงินประกันที่ตกลงในสัญญา
    [discount_amount] decimal(12,2) NOT NULL, -- ส่วนลด
    [discount_approved_by] int NULL REFERENCES dbo.employee(employee_id), -- ผู้จัดการอนุมัติส่วนลดพิเศษ
    [discount_approved_at] datetime2(0) NULL, -- วันเวลาอนุมัติส่วนลด
    [discount_reason] nvarchar(300) NULL, -- เหตุผลส่วนลดพิเศษ
    [pickup_mileage] int NULL, -- เลขไมล์ตอนส่งมอบ
    [return_mileage] int NULL, -- เลขไมล์ตอนคืน
    [pickup_fuel_percent] tinyint NULL, -- ระดับน้ำมันตอนส่งมอบ 0–100
    [return_fuel_percent] tinyint NULL, -- ระดับน้ำมันตอนคืน 0–100
    [pickup_condition] nvarchar(1000) NULL, -- สภาพรถก่อนเช่า
    [return_condition] nvarchar(1000) NULL, -- สภาพรถตอนคืน
    [status] varchar(20) NOT NULL, -- สถานะ OPEN / CLOSED / CANCELLED
    UNIQUE(rental_no),
    CHECK(due_return_at>pickup_at),
    CHECK(agreed_daily_rate>0 AND insurance_fee>=0 AND deductible_amount>=0 AND required_deposit>=0 AND discount_amount>=0),
    CHECK(insurance_selected=1 OR (insurance_fee=0 AND deductible_amount=0)),
    CHECK(pickup_fuel_percent BETWEEN 0 AND 100 AND return_fuel_percent BETWEEN 0 AND 100),
    CHECK(pickup_mileage>=0 AND return_mileage>=pickup_mileage),
    CHECK(actual_return_at IS NULL OR (actual_pickup_at IS NOT NULL AND actual_return_at>=actual_pickup_at AND return_employee_id IS NOT NULL AND return_mileage IS NOT NULL AND return_fuel_percent IS NOT NULL AND return_condition IS NOT NULL)),
    CHECK(actual_pickup_at IS NULL OR (pickup_mileage IS NOT NULL AND pickup_fuel_percent IS NOT NULL AND pickup_condition IS NOT NULL)),
    CHECK(status IN ('OPEN','CLOSED','CANCELLED')),
    CHECK(status<>'CLOSED' OR actual_return_at IS NOT NULL),
    CHECK(status<>'CANCELLED' OR actual_pickup_at IS NULL),
    CHECK((discount_amount=0 AND discount_approved_by IS NULL AND discount_approved_at IS NULL) OR (discount_amount>0 AND discount_approved_by IS NOT NULL AND discount_approved_at IS NOT NULL AND discount_reason IS NOT NULL))
);
-- ตาราง payment: การชำระเงิน (เพย์เมนต์)
CREATE TABLE dbo.payment (
    [payment_id] int IDENTITY(1,1) PRIMARY KEY, -- รหัสรายการชำระเงิน
    [rental_id] int NOT NULL REFERENCES dbo.rental(rental_id), -- สัญญาที่รับชำระหรือคืนเงิน
    [employee_id] int NOT NULL REFERENCES dbo.employee(employee_id), -- พนักงานผู้ดำเนินการ
    [payment_type] varchar(20) NOT NULL, -- ประเภท DEPOSIT / RENTAL / FINE / DEPOSIT_REFUND
    [amount] decimal(12,2) NOT NULL, -- ยอดเงินเป็นบวก ทิศทางเงินดูจากประเภท
    [payment_method] varchar(20) NOT NULL, -- วิธี CASH / TRANSFER / CARD / DEPOSIT
    [reference_no] nvarchar(100) NULL, -- เลขอ้างอิงธุรกรรม
    [paid_at] datetime2(0) NOT NULL, -- วันเวลาทำรายการ
    [status] varchar(20) NOT NULL, -- PENDING / SUCCESS / FAILED / CANCELLED
    [notes] nvarchar(300) NULL, -- หมายเหตุ
    CHECK(amount>0),
    CHECK(payment_type IN ('DEPOSIT','RENTAL','FINE','DEPOSIT_REFUND')),
    CHECK(payment_method IN ('CASH','TRANSFER','CARD','DEPOSIT')),
    CHECK(payment_method<>'DEPOSIT' OR payment_type IN ('RENTAL','FINE')),
    CHECK(status IN ('PENDING','SUCCESS','FAILED','CANCELLED'))
);
-- ตาราง fine_damage: ค่าปรับและความเสียหาย (ไฟน์ / แดเมจ)
CREATE TABLE dbo.fine_damage (
    [fine_damage_id] int IDENTITY(1,1) PRIMARY KEY, -- รหัสค่าปรับหรือความเสียหาย
    [rental_id] int NOT NULL REFERENCES dbo.rental(rental_id), -- สัญญาที่เกิดค่าปรับ
    [employee_id] int NOT NULL REFERENCES dbo.employee(employee_id), -- พนักงานบันทึกรายการ
    [fine_type] varchar(20) NOT NULL, -- LATE_RETURN / FUEL / EXCESS_MILEAGE / TRAFFIC / DAMAGE
    [description] nvarchar(1000) NOT NULL, -- รายละเอียดค่าปรับหรือความเสียหาย
    [evidence_url] nvarchar(500) NULL, -- ที่อยู่ไฟล์หลักฐานหรือภาพถ่าย
    [assessed_amount] decimal(12,2) NOT NULL, -- มูลค่าประเมินก่อนใช้เงื่อนไขประกัน
    [amount] decimal(12,2) NOT NULL, -- ยอดที่เรียกเก็บจริงจากลูกค้า
    [recorded_at] datetime2(0) NOT NULL, -- วันเวลาบันทึก
    [due_at] datetime2(0) NOT NULL, -- กำหนดชำระ
    [status] varchar(20) NOT NULL, -- UNPAID / PAID / WAIVED
    [waived_by_employee_id] int NULL REFERENCES dbo.employee(employee_id), -- ผู้จัดการอนุมัติยกเว้นค่าปรับ
    [waived_at] datetime2(0) NULL, -- วันเวลาอนุมัติยกเว้น
    [waiver_reason] nvarchar(300) NULL, -- เหตุผลยกเว้น
    CHECK(fine_type IN ('LATE_RETURN','FUEL','EXCESS_MILEAGE','TRAFFIC','DAMAGE')),
    CHECK(assessed_amount>=0 AND amount>=0 AND amount<=assessed_amount),
    CHECK(due_at>=recorded_at),
    CHECK(fine_type<>'DAMAGE' OR evidence_url IS NOT NULL),
    CHECK(status IN ('UNPAID','PAID','WAIVED')),
    CHECK((status='WAIVED' AND waived_by_employee_id IS NOT NULL AND waived_at IS NOT NULL AND waiver_reason IS NOT NULL) OR (status<>'WAIVED' AND waived_by_employee_id IS NULL AND waived_at IS NULL))
);
CREATE UNIQUE INDEX UX_rental_reservation ON dbo.rental(reservation_id) WHERE reservation_id IS NOT NULL;
CREATE INDEX IX_reservation_vehicle_time ON dbo.reservation(vehicle_id,pickup_at,return_at) INCLUDE(status,expires_at);
CREATE INDEX IX_rental_vehicle_time ON dbo.rental(vehicle_id,pickup_at,due_return_at) INCLUDE(status,actual_pickup_at,actual_return_at);
CREATE INDEX IX_payment_rental ON dbo.payment(rental_id) INCLUDE(payment_type,payment_method,amount,status);
CREATE INDEX IX_fine_rental ON dbo.fine_damage(rental_id) INCLUDE(amount,status);
COMMIT;
GO
USE car_rental_mini_project;
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
CREATE OR ALTER VIEW dbo.vw_RentalBalance AS
SELECT r.rental_id,r.rental_no,r.customer_id,r.vehicle_id,r.status,
    d.rental_days, CONVERT(decimal(12,2),d.rental_days*r.agreed_daily_rate+r.insurance_fee-r.discount_amount) AS rental_charge,
    COALESCE(f.fine_total,0) AS fine_total,COALESCE(p.rental_paid,0) AS rental_paid,COALESCE(p.fine_paid,0) AS fine_paid,
    CONVERT(decimal(12,2),d.rental_days*r.agreed_daily_rate+r.insurance_fee-r.discount_amount+COALESCE(f.fine_total,0)-COALESCE(p.rental_paid,0)-COALESCE(p.fine_paid,0)) AS outstanding,
    COALESCE(p.deposit_received,0) AS deposit_received,COALESCE(p.deposit_refunded,0) AS deposit_refunded,
    COALESCE(p.deposit_used,0) AS deposit_used,COALESCE(p.deposit_received,0)-COALESCE(p.deposit_refunded,0)-COALESCE(p.deposit_used,0) AS deposit_balance
FROM dbo.rental r
CROSS APPLY (SELECT CONVERT(int,CEILING(DATEDIFF_BIG(SECOND,r.pickup_at,r.due_return_at)/86400.0)) AS rental_days) d
OUTER APPLY (SELECT SUM(amount) AS fine_total FROM dbo.fine_damage WHERE rental_id=r.rental_id AND status<>'WAIVED') f
OUTER APPLY (SELECT
SUM(CASE WHEN payment_type='RENTAL' THEN amount ELSE 0 END) AS rental_paid,
SUM(CASE WHEN payment_type='FINE' THEN amount ELSE 0 END) AS fine_paid,
SUM(CASE WHEN payment_type='DEPOSIT' THEN amount ELSE 0 END) AS deposit_received,
SUM(CASE WHEN payment_type='DEPOSIT_REFUND' THEN amount ELSE 0 END) AS deposit_refunded,
SUM(CASE WHEN payment_method='DEPOSIT' THEN amount ELSE 0 END) AS deposit_used
FROM dbo.payment WHERE rental_id=r.rental_id AND status='SUCCESS') p;
GO

GO
CREATE OR ALTER VIEW dbo.vw_VehicleStatus AS
SELECT v.*,
CASE WHEN v.status='MAINTENANCE' THEN N'ซ่อมบำรุง'
WHEN EXISTS(SELECT 1 FROM dbo.rental r WHERE r.vehicle_id=v.vehicle_id AND r.status='OPEN' AND r.actual_pickup_at IS NOT NULL AND r.actual_return_at IS NULL) THEN N'กำลังเช่า'
WHEN EXISTS(SELECT 1 FROM dbo.reservation b WHERE b.vehicle_id=v.vehicle_id AND b.status IN ('PENDING','CONFIRMED') AND b.expires_at>SYSDATETIME() AND b.pickup_at<=SYSDATETIME() AND b.return_at>SYSDATETIME()) THEN N'ถูกจองในขณะนี้'
ELSE N'ว่างขณะนี้ ต้องตรวจช่วงเวลาก่อนเช่า' END AS status_thai
FROM dbo.vehicle v;
GO

-- usp_CreateReservation
GO
CREATE OR ALTER PROCEDURE dbo.usp_CreateReservation
@customer_id int,@vehicle_id int,@pickup_at datetime2(0),@return_at datetime2(0),@new_reservation_id int=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
  IF @pickup_at IS NULL OR @return_at IS NULL OR @pickup_at<SYSDATETIME() OR @return_at<=@pickup_at THROW 51009,N'วันเวลาจองไม่ถูกต้อง',1;
  DECLARE @reservation_id int=NULL,@rental_id int=NULL;
IF NOT EXISTS(SELECT 1 FROM dbo.customer WHERE customer_id=@customer_id AND status='ACTIVE'
 AND DATEADD(YEAR,20,birth_date)<=CONVERT(date,@pickup_at) AND license_expiry_date>=CONVERT(date,@return_at))
 THROW 51004,N'ลูกค้าถูกระงับ อายุไม่ครบ หรือใบขับขี่หมดอายุก่อนคืนรถ',1;
IF EXISTS(SELECT 1 FROM dbo.fine_damage f JOIN dbo.rental r ON r.rental_id=f.rental_id WHERE r.customer_id=@customer_id AND f.status='UNPAID' AND f.due_at<SYSDATETIME()) THROW 51005,N'มีค่าปรับค้างเกินกำหนด',1;IF NOT EXISTS(SELECT 1 FROM dbo.vehicle WHERE vehicle_id=@vehicle_id AND status<>'MAINTENANCE') THROW 51006,N'ไม่พบรถ หรือรถซ่อมบำรุง',1;
IF EXISTS(SELECT 1 FROM dbo.reservation WHERE vehicle_id=@vehicle_id AND status IN ('PENDING','CONFIRMED') AND expires_at>SYSDATETIME()
 AND (@reservation_id IS NULL OR reservation_id<>@reservation_id) AND pickup_at<@return_at AND @pickup_at<return_at)
 THROW 51007,N'ช่วงเวลาทับซ้อนการจองอื่น',1;
IF EXISTS(SELECT 1 FROM dbo.rental WHERE vehicle_id=@vehicle_id AND status<>'CANCELLED' AND actual_return_at IS NULL
 AND (@rental_id IS NULL OR rental_id<>@rental_id) AND (pickup_at<@return_at AND @pickup_at<due_return_at OR actual_pickup_at IS NOT NULL AND due_return_at<SYSDATETIME()))
 THROW 51008,N'รถถูกเช่าหรือมีสัญญาทับซ้อน',1;
  INSERT dbo.reservation(reservation_no,customer_id,vehicle_id,reserved_at,pickup_at,return_at,expires_at,status)
  VALUES('RS-'+LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),26),@customer_id,@vehicle_id,SYSDATETIME(),@pickup_at,@return_at,DATEADD(HOUR,3,@pickup_at),'CONFIRMED');
  SET @new_reservation_id=CONVERT(int,SCOPE_IDENTITY());
  SELECT @new_reservation_id AS reservation_id;

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_ExpireReservations
GO
CREATE OR ALTER PROCEDURE dbo.usp_ExpireReservations

AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
UPDATE dbo.reservation SET status='EXPIRED' WHERE status IN ('PENDING','CONFIRMED') AND expires_at<=SYSDATETIME();
SELECT @@ROWCOUNT AS expired_count;
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_CancelReservation
GO
CREATE OR ALTER PROCEDURE dbo.usp_CancelReservation
@reservation_id int,@reason nvarchar(300)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF NULLIF(LTRIM(RTRIM(@reason)),N'') IS NULL THROW 51010,N'กรุณาระบุเหตุผลยกเลิก',1;
UPDATE dbo.reservation SET status='CANCELLED',cancelled_at=SYSDATETIME(),cancellation_reason=@reason WHERE reservation_id=@reservation_id AND status IN ('PENDING','CONFIRMED');
IF @@ROWCOUNT<>1 THROW 51011,N'ยกเลิกการจองนี้ไม่ได้',1;
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_OpenRental
GO
CREATE OR ALTER PROCEDURE dbo.usp_OpenRental
@customer_id int,@vehicle_id int,@employee_id int,@pickup_at datetime2(0),@return_at datetime2(0),
@reservation_id int=NULL,@insurance_selected bit=0,@insurance_fee decimal(12,2)=0,@deductible_amount decimal(12,2)=0,
@discount_amount decimal(12,2)=0,@manager_id int=NULL,@discount_reason nvarchar(300)=NULL,@new_rental_id int=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF @pickup_at IS NULL OR @return_at IS NULL OR @return_at<=@pickup_at OR @return_at<=SYSDATETIME() THROW 51012,N'เวลาเช่าไม่ถูกต้อง',1;
DECLARE @rental_id int=NULL,@rate decimal(12,2),@deposit decimal(12,2);
IF NOT EXISTS(SELECT 1 FROM dbo.employee WHERE employee_id=@employee_id AND status='ACTIVE') THROW 51003,N'พนักงานไม่พร้อมใช้งาน',1;IF NOT EXISTS(SELECT 1 FROM dbo.customer WHERE customer_id=@customer_id AND status='ACTIVE'
 AND DATEADD(YEAR,20,birth_date)<=CONVERT(date,@pickup_at) AND license_expiry_date>=CONVERT(date,@return_at))
 THROW 51004,N'ลูกค้าถูกระงับ อายุไม่ครบ หรือใบขับขี่หมดอายุก่อนคืนรถ',1;
IF EXISTS(SELECT 1 FROM dbo.fine_damage f JOIN dbo.rental r ON r.rental_id=f.rental_id WHERE r.customer_id=@customer_id AND f.status='UNPAID' AND f.due_at<SYSDATETIME()) THROW 51005,N'มีค่าปรับค้างเกินกำหนด',1;IF NOT EXISTS(SELECT 1 FROM dbo.vehicle WHERE vehicle_id=@vehicle_id AND status<>'MAINTENANCE') THROW 51006,N'ไม่พบรถ หรือรถซ่อมบำรุง',1;
IF EXISTS(SELECT 1 FROM dbo.reservation WHERE vehicle_id=@vehicle_id AND status IN ('PENDING','CONFIRMED') AND expires_at>SYSDATETIME()
 AND (@reservation_id IS NULL OR reservation_id<>@reservation_id) AND pickup_at<@return_at AND @pickup_at<return_at)
 THROW 51007,N'ช่วงเวลาทับซ้อนการจองอื่น',1;
IF EXISTS(SELECT 1 FROM dbo.rental WHERE vehicle_id=@vehicle_id AND status<>'CANCELLED' AND actual_return_at IS NULL
 AND (@rental_id IS NULL OR rental_id<>@rental_id) AND (pickup_at<@return_at AND @pickup_at<due_return_at OR actual_pickup_at IS NOT NULL AND due_return_at<SYSDATETIME()))
 THROW 51008,N'รถถูกเช่าหรือมีสัญญาทับซ้อน',1;
IF @reservation_id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.reservation WHERE reservation_id=@reservation_id AND customer_id=@customer_id AND vehicle_id=@vehicle_id AND status='CONFIRMED' AND expires_at>SYSDATETIME() AND pickup_at=@pickup_at AND return_at=@return_at) THROW 51013,N'การจองไม่ตรงกับสัญญาหรือหมดอายุ',1;
IF @discount_amount<0 OR @insurance_fee<0 OR @deductible_amount<0 OR (@insurance_selected=0 AND (@insurance_fee<>0 OR @deductible_amount<>0)) THROW 51014,N'ส่วนลดหรือประกันไม่ถูกต้อง',1;
IF @discount_amount>0 AND (NULLIF(LTRIM(RTRIM(@discount_reason)),N'') IS NULL OR NOT EXISTS(SELECT 1 FROM dbo.employee WHERE employee_id=@manager_id AND role='MANAGER' AND status='ACTIVE')) THROW 51015,N'ส่วนลดต้องอนุมัติโดยผู้จัดการพร้อมเหตุผล',1;
SELECT @rate=daily_rate,@deposit=deposit_amount FROM dbo.vehicle WHERE vehicle_id=@vehicle_id;
IF @discount_amount>CEILING(DATEDIFF_BIG(SECOND,@pickup_at,@return_at)/86400.0)*@rate+@insurance_fee THROW 51016,N'ส่วนลดเกินค่าเช่า',1;
INSERT dbo.rental(rental_no,reservation_id,customer_id,vehicle_id,pickup_employee_id,pickup_at,due_return_at,agreed_daily_rate,insurance_selected,insurance_fee,deductible_amount,required_deposit,discount_amount,discount_approved_by,discount_approved_at,discount_reason,status)
VALUES('RT-'+LEFT(REPLACE(CONVERT(varchar(36),NEWID()),'-',''),26),@reservation_id,@customer_id,@vehicle_id,@employee_id,@pickup_at,@return_at,@rate,@insurance_selected,@insurance_fee,@deductible_amount,@deposit,@discount_amount,CASE WHEN @discount_amount>0 THEN @manager_id END,CASE WHEN @discount_amount>0 THEN SYSDATETIME() END,CASE WHEN @discount_amount>0 THEN @discount_reason END,'OPEN');
SET @rental_id=CONVERT(int,SCOPE_IDENTITY());
SET @new_rental_id=@rental_id;
UPDATE dbo.reservation SET status='CONVERTED' WHERE reservation_id=@reservation_id;
SELECT @rental_id AS rental_id;

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_RecordPayment
GO
CREATE OR ALTER PROCEDURE dbo.usp_RecordPayment
@rental_id int,@employee_id int,@payment_type varchar(20),@amount decimal(12,2),@payment_method varchar(20),@reference_no nvarchar(100)=NULL
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF NOT EXISTS(SELECT 1 FROM dbo.employee WHERE employee_id=@employee_id AND status='ACTIVE') THROW 51003,N'พนักงานไม่พร้อมใช้งาน',1;
IF @amount IS NULL OR @amount<=0 OR @payment_type NOT IN ('DEPOSIT','RENTAL','FINE','DEPOSIT_REFUND') OR @payment_method NOT IN ('CASH','TRANSFER','CARD','DEPOSIT') THROW 51017,N'ข้อมูลการชำระไม่ถูกต้อง',1;
IF NOT EXISTS(SELECT 1 FROM dbo.rental WHERE rental_id=@rental_id AND status='OPEN') THROW 51018,N'สัญญาไม่ได้เปิดอยู่',1;
DECLARE @rent_due decimal(12,2),@fine_due decimal(12,2),@dep decimal(12,2),@received decimal(12,2),@required decimal(12,2),@returned datetime2(0);
SELECT @rent_due=rental_charge-rental_paid,@fine_due=fine_total-fine_paid,@dep=deposit_balance,@received=deposit_received FROM dbo.vw_RentalBalance WHERE rental_id=@rental_id;
SELECT @required=required_deposit,@returned=actual_return_at FROM dbo.rental WHERE rental_id=@rental_id;
IF @payment_type='DEPOSIT' AND @amount>@required-@received THROW 51019,N'รับเงินประกันเกินยอดกำหนด',1;
IF @payment_type='RENTAL' AND @amount>@rent_due THROW 51020,N'ชำระค่าเช่าเกินยอดค้าง',1;
IF @payment_type='FINE' AND @amount>@fine_due THROW 51021,N'ชำระค่าปรับเกินยอดค้าง',1;
IF @payment_method='DEPOSIT' AND (@payment_type NOT IN ('RENTAL','FINE') OR @returned IS NULL OR @amount>@dep) THROW 51022,N'ใช้เงินประกันได้หลังคืนรถและไม่เกินยอดคงเหลือ',1;
IF @payment_type='DEPOSIT_REFUND' AND (@returned IS NULL OR @rent_due+@fine_due<>0 OR @amount>@dep OR @payment_method='DEPOSIT') THROW 51023,N'คืนเงินประกันได้หลังคืนรถ ชำระครบ และไม่เกินยอดคงเหลือ',1;
INSERT dbo.payment(rental_id,employee_id,payment_type,amount,payment_method,reference_no,paid_at,status) VALUES(@rental_id,@employee_id,@payment_type,@amount,@payment_method,@reference_no,SYSDATETIME(),'SUCCESS');
IF @payment_type='FINE' AND NOT EXISTS(SELECT 1 FROM dbo.vw_RentalBalance WHERE rental_id=@rental_id AND fine_total>fine_paid)
 UPDATE dbo.fine_damage SET status='PAID' WHERE rental_id=@rental_id AND status='UNPAID';
SELECT * FROM dbo.vw_RentalBalance WHERE rental_id=@rental_id;

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_StartRental
GO
CREATE OR ALTER PROCEDURE dbo.usp_StartRental
@rental_id int,@employee_id int,@mileage int,@fuel_percent tinyint,@condition nvarchar(1000)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF NOT EXISTS(SELECT 1 FROM dbo.employee WHERE employee_id=@employee_id AND status='ACTIVE') THROW 51003,N'พนักงานไม่พร้อมใช้งาน',1;
DECLARE @customer_id int,@vehicle_id int,@pickup_at datetime2(0),@return_at datetime2(0),@reservation_id int;
SELECT @customer_id=customer_id,@vehicle_id=vehicle_id,@pickup_at=pickup_at,@return_at=due_return_at,@reservation_id=reservation_id FROM dbo.rental WHERE rental_id=@rental_id AND status='OPEN' AND actual_pickup_at IS NULL;
IF @customer_id IS NULL OR @return_at<=SYSDATETIME() OR @pickup_at>DATEADD(HOUR,1,SYSDATETIME()) THROW 51024,N'สัญญาไม่พร้อมส่งมอบ หรือยังไม่ถึงเวลารับรถ',1;
IF NOT EXISTS(SELECT 1 FROM dbo.customer WHERE customer_id=@customer_id AND status='ACTIVE'
 AND DATEADD(YEAR,20,birth_date)<=CONVERT(date,@pickup_at) AND license_expiry_date>=CONVERT(date,@return_at))
 THROW 51004,N'ลูกค้าถูกระงับ อายุไม่ครบ หรือใบขับขี่หมดอายุก่อนคืนรถ',1;
IF EXISTS(SELECT 1 FROM dbo.fine_damage f JOIN dbo.rental r ON r.rental_id=f.rental_id WHERE r.customer_id=@customer_id AND f.status='UNPAID' AND f.due_at<SYSDATETIME()) THROW 51005,N'มีค่าปรับค้างเกินกำหนด',1;IF NOT EXISTS(SELECT 1 FROM dbo.vehicle WHERE vehicle_id=@vehicle_id AND status<>'MAINTENANCE') THROW 51006,N'ไม่พบรถ หรือรถซ่อมบำรุง',1;
IF EXISTS(SELECT 1 FROM dbo.reservation WHERE vehicle_id=@vehicle_id AND status IN ('PENDING','CONFIRMED') AND expires_at>SYSDATETIME()
 AND (@reservation_id IS NULL OR reservation_id<>@reservation_id) AND pickup_at<@return_at AND @pickup_at<return_at)
 THROW 51007,N'ช่วงเวลาทับซ้อนการจองอื่น',1;
IF EXISTS(SELECT 1 FROM dbo.rental WHERE vehicle_id=@vehicle_id AND status<>'CANCELLED' AND actual_return_at IS NULL
 AND (@rental_id IS NULL OR rental_id<>@rental_id) AND (pickup_at<@return_at AND @pickup_at<due_return_at OR actual_pickup_at IS NOT NULL AND due_return_at<SYSDATETIME()))
 THROW 51008,N'รถถูกเช่าหรือมีสัญญาทับซ้อน',1;
IF @mileage IS NULL OR @fuel_percent IS NULL OR @fuel_percent>100 OR NULLIF(LTRIM(RTRIM(@condition)),N'') IS NULL OR @mileage<(SELECT current_mileage FROM dbo.vehicle WHERE vehicle_id=@vehicle_id) THROW 51025,N'เลขไมล์ น้ำมัน หรือสภาพรถไม่ถูกต้อง',1;
IF EXISTS(SELECT 1 FROM dbo.rental WHERE vehicle_id=@vehicle_id AND rental_id<>@rental_id AND status='OPEN' AND actual_pickup_at IS NOT NULL AND actual_return_at IS NULL) THROW 51008,N'รถยังไม่คืนจากสัญญาอื่น',1;
IF EXISTS(SELECT 1 FROM dbo.rental r JOIN dbo.vw_RentalBalance b ON b.rental_id=r.rental_id WHERE r.rental_id=@rental_id AND b.deposit_balance<r.required_deposit) THROW 51026,N'ยังรับเงินประกันไม่ครบ',1;
UPDATE dbo.rental SET actual_pickup_at=SYSDATETIME(),pickup_employee_id=@employee_id,pickup_mileage=@mileage,pickup_fuel_percent=@fuel_percent,pickup_condition=@condition WHERE rental_id=@rental_id;
UPDATE dbo.vehicle SET status='RENTED',current_mileage=@mileage WHERE vehicle_id=@vehicle_id;

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_AddFine
GO
CREATE OR ALTER PROCEDURE dbo.usp_AddFine
@rental_id int,@employee_id int,@fine_type varchar(20),@description nvarchar(1000),@assessed_amount decimal(12,2),@evidence_url nvarchar(500)=NULL,@new_fine_damage_id int=NULL OUTPUT
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF NOT EXISTS(SELECT 1 FROM dbo.employee WHERE employee_id=@employee_id AND status='ACTIVE') THROW 51003,N'พนักงานไม่พร้อมใช้งาน',1;
IF NOT EXISTS(SELECT 1 FROM dbo.rental WHERE rental_id=@rental_id AND status='OPEN' AND actual_pickup_at IS NOT NULL) THROW 51027,N'สัญญาไม่พร้อมบันทึกค่าปรับ',1;
IF @assessed_amount IS NULL OR @assessed_amount<=0 OR NULLIF(LTRIM(RTRIM(@description)),N'') IS NULL OR @fine_type NOT IN ('LATE_RETURN','FUEL','EXCESS_MILEAGE','TRAFFIC','DAMAGE') THROW 51028,N'ข้อมูลค่าปรับไม่ถูกต้อง',1;
IF @fine_type='DAMAGE' AND NULLIF(LTRIM(RTRIM(@evidence_url)),N'') IS NULL THROW 51029,N'ความเสียหายต้องมีหลักฐาน',1;
-- คิดจำนวนเต็มก่อน ผู้จัดการ/ประกันต้องประเมินยอดเรียกเก็บตามสัญญาจริง ไม่ลดอัตโนมัติทุกกรณี
INSERT dbo.fine_damage(rental_id,employee_id,fine_type,description,evidence_url,assessed_amount,amount,recorded_at,due_at,status)
VALUES(@rental_id,@employee_id,@fine_type,@description,@evidence_url,@assessed_amount,@assessed_amount,SYSDATETIME(),DATEADD(DAY,7,SYSDATETIME()),'UNPAID');
SET @new_fine_damage_id=CONVERT(int,SCOPE_IDENTITY());
SELECT @new_fine_damage_id AS fine_damage_id;

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_ReturnCar
GO
CREATE OR ALTER PROCEDURE dbo.usp_ReturnCar
@rental_id int,@employee_id int,@mileage int,@fuel_percent tinyint,@condition nvarchar(1000),@needs_maintenance bit=0,@late_fee_per_hour decimal(12,2)=100
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF NOT EXISTS(SELECT 1 FROM dbo.employee WHERE employee_id=@employee_id AND status='ACTIVE') THROW 51003,N'พนักงานไม่พร้อมใช้งาน',1;
DECLARE @vehicle_id int,@start datetime2(0),@due datetime2(0),@pickup_mileage int,@now datetime2(0)=SYSDATETIME(),@late decimal(12,2);
SELECT @vehicle_id=vehicle_id,@start=actual_pickup_at,@due=due_return_at,@pickup_mileage=pickup_mileage FROM dbo.rental WHERE rental_id=@rental_id AND status='OPEN' AND actual_pickup_at IS NOT NULL AND actual_return_at IS NULL;
IF @vehicle_id IS NULL THROW 51030,N'สัญญานี้ยังไม่รับรถหรือคืนแล้ว',1;
IF @mileage IS NULL OR @mileage<@pickup_mileage OR @fuel_percent IS NULL OR @fuel_percent>100 OR @late_fee_per_hour IS NULL OR @late_fee_per_hour<0 OR NULLIF(LTRIM(RTRIM(@condition)),N'') IS NULL THROW 51031,N'ข้อมูลรับคืนไม่ถูกต้อง',1;
UPDATE dbo.rental SET actual_return_at=@now,return_employee_id=@employee_id,return_mileage=@mileage,return_fuel_percent=@fuel_percent,return_condition=@condition WHERE rental_id=@rental_id;
UPDATE dbo.vehicle SET current_mileage=@mileage,status=CASE WHEN @needs_maintenance=1 THEN 'MAINTENANCE' ELSE 'AVAILABLE' END WHERE vehicle_id=@vehicle_id;
IF @now>DATEADD(HOUR,1,@due) AND @late_fee_per_hour>0 BEGIN
 SET @late=CEILING(DATEDIFF_BIG(SECOND,DATEADD(HOUR,1,@due),@now)/3600.0)*@late_fee_per_hour;
 INSERT dbo.fine_damage(rental_id,employee_id,fine_type,description,assessed_amount,amount,recorded_at,due_at,status) VALUES(@rental_id,@employee_id,'LATE_RETURN',N'คืนช้าเกินเวลาผ่อนผัน 1 ชั่วโมง',@late,@late,@now,DATEADD(DAY,7,@now),'UNPAID');
END;
SELECT * FROM dbo.vw_RentalBalance WHERE rental_id=@rental_id;

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_WaiveFine
GO
CREATE OR ALTER PROCEDURE dbo.usp_WaiveFine
@fine_damage_id int,@employee_id int,@reason nvarchar(300)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF NOT EXISTS(SELECT 1 FROM dbo.employee WHERE employee_id=@employee_id AND role='MANAGER' AND status='ACTIVE') THROW 51032,N'ผู้จัดการเท่านั้นที่ยกเว้นค่าปรับได้',1;
IF NULLIF(LTRIM(RTRIM(@reason)),N'') IS NULL THROW 51033,N'ต้องระบุเหตุผล',1;
DECLARE @rental_id int;
SELECT @rental_id=f.rental_id FROM dbo.fine_damage f JOIN dbo.rental r ON r.rental_id=f.rental_id WHERE f.fine_damage_id=@fine_damage_id AND f.status='UNPAID' AND r.status='OPEN';
IF @rental_id IS NULL OR EXISTS(SELECT 1 FROM dbo.payment WHERE rental_id=@rental_id AND payment_type='FINE' AND status='SUCCESS') THROW 51034,N'ยกเว้นได้ก่อนรับชำระค่าปรับเท่านั้น',1;
UPDATE dbo.fine_damage SET status='WAIVED',waived_by_employee_id=@employee_id,waived_at=SYSDATETIME(),waiver_reason=@reason WHERE fine_damage_id=@fine_damage_id;

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_CloseRental
GO
CREATE OR ALTER PROCEDURE dbo.usp_CloseRental
@rental_id int
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF NOT EXISTS(SELECT 1 FROM dbo.rental WHERE rental_id=@rental_id AND status='OPEN' AND actual_return_at IS NOT NULL) THROW 51035,N'ต้องคืนและตรวจรถก่อนปิดสัญญา',1;
IF EXISTS(SELECT 1 FROM dbo.vw_RentalBalance WHERE rental_id=@rental_id AND (outstanding<>0 OR deposit_balance<>0)) THROW 51036,N'ต้องชำระครบและจัดการเงินประกันครบก่อนปิดสัญญา',1;
UPDATE dbo.rental SET status='CLOSED' WHERE rental_id=@rental_id;
UPDATE dbo.fine_damage SET status='PAID' WHERE rental_id=@rental_id AND status='UNPAID';

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_ExtendRental
GO
CREATE OR ALTER PROCEDURE dbo.usp_ExtendRental
@rental_id int,@employee_id int,@new_return_at datetime2(0)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF NOT EXISTS(SELECT 1 FROM dbo.employee WHERE employee_id=@employee_id AND status='ACTIVE') THROW 51003,N'พนักงานไม่พร้อมใช้งาน',1;
DECLARE @customer_id int,@vehicle_id int,@pickup_at datetime2(0),@return_at datetime2(0)=@new_return_at,@reservation_id int,@old datetime2(0);
SELECT @customer_id=customer_id,@vehicle_id=vehicle_id,@pickup_at=pickup_at,@reservation_id=reservation_id,@old=due_return_at FROM dbo.rental WHERE rental_id=@rental_id AND status='OPEN' AND actual_return_at IS NULL;
IF @customer_id IS NULL OR @new_return_at IS NULL OR @new_return_at<=@old OR @new_return_at<=SYSDATETIME() THROW 51037,N'เวลาต่อเช่าไม่ถูกต้อง',1;
IF NOT EXISTS(SELECT 1 FROM dbo.customer WHERE customer_id=@customer_id AND status='ACTIVE'
 AND DATEADD(YEAR,20,birth_date)<=CONVERT(date,@pickup_at) AND license_expiry_date>=CONVERT(date,@return_at))
 THROW 51004,N'ลูกค้าถูกระงับ อายุไม่ครบ หรือใบขับขี่หมดอายุก่อนคืนรถ',1;
IF EXISTS(SELECT 1 FROM dbo.fine_damage f JOIN dbo.rental r ON r.rental_id=f.rental_id WHERE r.customer_id=@customer_id AND f.status='UNPAID' AND f.due_at<SYSDATETIME()) THROW 51005,N'มีค่าปรับค้างเกินกำหนด',1;IF NOT EXISTS(SELECT 1 FROM dbo.vehicle WHERE vehicle_id=@vehicle_id AND status<>'MAINTENANCE') THROW 51006,N'ไม่พบรถ หรือรถซ่อมบำรุง',1;
IF EXISTS(SELECT 1 FROM dbo.reservation WHERE vehicle_id=@vehicle_id AND status IN ('PENDING','CONFIRMED') AND expires_at>SYSDATETIME()
 AND (@reservation_id IS NULL OR reservation_id<>@reservation_id) AND pickup_at<@return_at AND @pickup_at<return_at)
 THROW 51007,N'ช่วงเวลาทับซ้อนการจองอื่น',1;
IF EXISTS(SELECT 1 FROM dbo.rental WHERE vehicle_id=@vehicle_id AND status<>'CANCELLED' AND actual_return_at IS NULL
 AND (@rental_id IS NULL OR rental_id<>@rental_id) AND (pickup_at<@return_at AND @pickup_at<due_return_at OR actual_pickup_at IS NOT NULL AND due_return_at<SYSDATETIME()))
 THROW 51008,N'รถถูกเช่าหรือมีสัญญาทับซ้อน',1;
UPDATE dbo.rental SET due_return_at=@new_return_at WHERE rental_id=@rental_id;

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_SetMaintenance
GO
CREATE OR ALTER PROCEDURE dbo.usp_SetMaintenance
@vehicle_id int,@employee_id int,@needs_maintenance bit
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF NOT EXISTS(SELECT 1 FROM dbo.employee WHERE employee_id=@employee_id AND status='ACTIVE') THROW 51003,N'พนักงานไม่พร้อมใช้งาน',1;
IF NOT EXISTS(SELECT 1 FROM dbo.vehicle WHERE vehicle_id=@vehicle_id) THROW 51038,N'ไม่พบรถ',1;
IF EXISTS(SELECT 1 FROM dbo.rental WHERE vehicle_id=@vehicle_id AND status='OPEN' AND actual_return_at IS NULL) OR EXISTS(SELECT 1 FROM dbo.reservation WHERE vehicle_id=@vehicle_id AND status IN ('PENDING','CONFIRMED') AND expires_at>SYSDATETIME()) THROW 51039,N'รถยังมีสัญญาหรือการจอง ต้องจัดการก่อน',1;
UPDATE dbo.vehicle SET status=CASE WHEN @needs_maintenance=1 THEN 'MAINTENANCE' ELSE 'AVAILABLE' END WHERE vehicle_id=@vehicle_id;

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_UpdateCustomerSuspensions
GO
CREATE OR ALTER PROCEDURE dbo.usp_UpdateCustomerSuspensions

AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
UPDATE c SET status='SUSPENDED' FROM dbo.customer c WHERE EXISTS(SELECT 1 FROM dbo.rental r JOIN dbo.fine_damage f ON f.rental_id=r.rental_id WHERE r.customer_id=c.customer_id AND f.status='UNPAID' AND f.due_at<SYSDATETIME());
SELECT @@ROWCOUNT AS suspended_count;
-- ไม่ปลดระงับอัตโนมัติ เพราะอาจมีเหตุผลระงับอื่น ผู้จัดการตรวจแล้วแก้สถานะ

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_CancelRental
GO
CREATE OR ALTER PROCEDURE dbo.usp_CancelRental
@rental_id int,@reason nvarchar(300)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF NULLIF(LTRIM(RTRIM(@reason)),N'') IS NULL THROW 51040,N'ต้องระบุเหตุผล',1;
IF NOT EXISTS(SELECT 1 FROM dbo.rental WHERE rental_id=@rental_id AND status='OPEN' AND actual_pickup_at IS NULL) THROW 51041,N'ยกเลิกได้ก่อนส่งมอบเท่านั้น',1;
IF EXISTS(SELECT 1 FROM dbo.payment WHERE rental_id=@rental_id AND status='SUCCESS') THROW 51042,N'สัญญามีรายการเงินแล้ว ต้องให้ผู้ดูแลจัดการคืนเงินก่อนยกเลิก',1;
UPDATE dbo.reservation SET status='CANCELLED',cancelled_at=SYSDATETIME(),cancellation_reason=@reason WHERE reservation_id=(SELECT reservation_id FROM dbo.rental WHERE rental_id=@rental_id);
UPDATE dbo.rental SET status='CANCELLED' WHERE rental_id=@rental_id;

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- usp_AssessInsuredDamage
GO
CREATE OR ALTER PROCEDURE dbo.usp_AssessInsuredDamage
@fine_damage_id int,@employee_id int,@charged_amount decimal(12,2),@reason nvarchar(300)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51001,N'เรียก procedure นี้นอก transaction อื่น',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lock_result int;
  EXEC @lock_result=sys.sp_getapplock @Resource=N'CarRental7Workflow',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=10000;
  IF @lock_result<0 THROW 51002,N'ระบบกำลังทำรายการอื่น กรุณาลองใหม่',1;
IF NOT EXISTS(SELECT 1 FROM dbo.employee WHERE employee_id=@employee_id AND role='MANAGER' AND status='ACTIVE') THROW 51043,N'ผู้จัดการต้องยืนยันความคุ้มครอง',1;
DECLARE @rental_id int,@assessed decimal(12,2),@deductible decimal(12,2);
SELECT @rental_id=f.rental_id,@assessed=f.assessed_amount,@deductible=r.deductible_amount FROM dbo.fine_damage f JOIN dbo.rental r ON r.rental_id=f.rental_id WHERE f.fine_damage_id=@fine_damage_id AND f.fine_type='DAMAGE' AND f.status='UNPAID' AND r.status='OPEN' AND r.insurance_selected=1;
IF @rental_id IS NULL OR @charged_amount IS NULL OR @charged_amount<0 OR @charged_amount>@assessed OR @charged_amount>@deductible OR NULLIF(LTRIM(RTRIM(@reason)),N'') IS NULL THROW 51044,N'ยอดประเมินประกันไม่ถูกต้อง',1;
IF EXISTS(SELECT 1 FROM dbo.payment WHERE rental_id=@rental_id AND payment_type='FINE' AND status='SUCCESS') THROW 51045,N'ต้องประเมินก่อนรับชำระค่าปรับ',1;
UPDATE dbo.fine_damage SET amount=@charged_amount,description=LEFT(description,600)+N' | ผู้จัดการ '+CONVERT(nvarchar(20),@employee_id)+N' ยืนยันความคุ้มครอง: '+@reason WHERE fine_damage_id=@fine_damage_id;

  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
  THROW;
 END CATCH
END;
GO

-- บทบาทใช้งานจริง: บังคับให้ใช้ procedure; ไม่เพิ่มตารางในระบบ
IF DATABASE_PRINCIPAL_ID('car_rental_operator') IS NULL CREATE ROLE car_rental_operator;
GRANT SELECT ON SCHEMA::dbo TO car_rental_operator;
DENY INSERT,UPDATE,DELETE ON SCHEMA::dbo TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_CreateReservation TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_ExpireReservations TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_CancelReservation TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_OpenRental TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_RecordPayment TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_StartRental TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_AddFine TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_ReturnCar TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_WaiveFine TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_CloseRental TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_ExtendRental TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_SetMaintenance TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_UpdateCustomerSuspensions TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_CancelRental TO car_rental_operator;
GRANT EXECUTE ON dbo.usp_AssessInsuredDamage TO car_rental_operator;
GO
USE car_rental_mini_project;
SET NOCOUNT ON; SET XACT_ABORT ON;
-- รันทั้งไฟล์ครั้งเดียว ไม่ใส่ GO และไม่เพิ่มข้อมูลทับของเดิม
BEGIN TRY
BEGIN TRANSACTION;
IF EXISTS(SELECT 1 FROM dbo.customer) OR EXISTS(SELECT 1 FROM dbo.vehicle) OR EXISTS(SELECT 1 FROM dbo.employee) OR EXISTS(SELECT 1 FROM dbo.reservation) OR EXISTS(SELECT 1 FROM dbo.rental) OR EXISTS(SELECT 1 FROM dbo.payment) OR EXISTS(SELECT 1 FROM dbo.fine_damage) THROW 51100,N'ต้องใส่ข้อมูลตัวอย่างในชุดตารางว่างเท่านั้น',1;
-- ลูกค้า (คัสตอเมอร์): 100 รายการ
SET IDENTITY_INSERT dbo.customer ON;
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (1,N'ลูกค้าทดสอบ 001','1985-01-01',N'DEMO-ID-001',N'DEMO-LIC-001','2035-12-31',N'0800000001',N'demo1@example.test',N'ที่อยู่สมมติ 1','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (2,N'ลูกค้าทดสอบ 002','1985-01-01',N'DEMO-ID-002',N'DEMO-LIC-002','2035-12-31',N'0800000002',N'demo2@example.test',N'ที่อยู่สมมติ 2','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (3,N'ลูกค้าทดสอบ 003','1985-01-01',N'DEMO-ID-003',N'DEMO-LIC-003','2035-12-31',N'0800000003',N'demo3@example.test',N'ที่อยู่สมมติ 3','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (4,N'ลูกค้าทดสอบ 004','1985-01-01',N'DEMO-ID-004',N'DEMO-LIC-004','2035-12-31',N'0800000004',N'demo4@example.test',N'ที่อยู่สมมติ 4','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (5,N'ลูกค้าทดสอบ 005','1985-01-01',N'DEMO-ID-005',N'DEMO-LIC-005','2035-12-31',N'0800000005',N'demo5@example.test',N'ที่อยู่สมมติ 5','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (6,N'ลูกค้าทดสอบ 006','1985-01-01',N'DEMO-ID-006',N'DEMO-LIC-006','2035-12-31',N'0800000006',N'demo6@example.test',N'ที่อยู่สมมติ 6','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (7,N'ลูกค้าทดสอบ 007','1985-01-01',N'DEMO-ID-007',N'DEMO-LIC-007','2035-12-31',N'0800000007',N'demo7@example.test',N'ที่อยู่สมมติ 7','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (8,N'ลูกค้าทดสอบ 008','1985-01-01',N'DEMO-ID-008',N'DEMO-LIC-008','2035-12-31',N'0800000008',N'demo8@example.test',N'ที่อยู่สมมติ 8','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (9,N'ลูกค้าทดสอบ 009','1985-01-01',N'DEMO-ID-009',N'DEMO-LIC-009','2035-12-31',N'0800000009',N'demo9@example.test',N'ที่อยู่สมมติ 9','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (10,N'ลูกค้าทดสอบ 010','1985-01-01',N'DEMO-ID-010',N'DEMO-LIC-010','2035-12-31',N'0800000010',N'demo10@example.test',N'ที่อยู่สมมติ 10','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (11,N'ลูกค้าทดสอบ 011','1985-01-01',N'DEMO-ID-011',N'DEMO-LIC-011','2035-12-31',N'0800000011',N'demo11@example.test',N'ที่อยู่สมมติ 11','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (12,N'ลูกค้าทดสอบ 012','1985-01-01',N'DEMO-ID-012',N'DEMO-LIC-012','2035-12-31',N'0800000012',N'demo12@example.test',N'ที่อยู่สมมติ 12','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (13,N'ลูกค้าทดสอบ 013','1985-01-01',N'DEMO-ID-013',N'DEMO-LIC-013','2035-12-31',N'0800000013',N'demo13@example.test',N'ที่อยู่สมมติ 13','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (14,N'ลูกค้าทดสอบ 014','1985-01-01',N'DEMO-ID-014',N'DEMO-LIC-014','2035-12-31',N'0800000014',N'demo14@example.test',N'ที่อยู่สมมติ 14','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (15,N'ลูกค้าทดสอบ 015','1985-01-01',N'DEMO-ID-015',N'DEMO-LIC-015','2035-12-31',N'0800000015',N'demo15@example.test',N'ที่อยู่สมมติ 15','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (16,N'ลูกค้าทดสอบ 016','1985-01-01',N'DEMO-ID-016',N'DEMO-LIC-016','2035-12-31',N'0800000016',N'demo16@example.test',N'ที่อยู่สมมติ 16','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (17,N'ลูกค้าทดสอบ 017','1985-01-01',N'DEMO-ID-017',N'DEMO-LIC-017','2035-12-31',N'0800000017',N'demo17@example.test',N'ที่อยู่สมมติ 17','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (18,N'ลูกค้าทดสอบ 018','1985-01-01',N'DEMO-ID-018',N'DEMO-LIC-018','2035-12-31',N'0800000018',N'demo18@example.test',N'ที่อยู่สมมติ 18','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (19,N'ลูกค้าทดสอบ 019','1985-01-01',N'DEMO-ID-019',N'DEMO-LIC-019','2035-12-31',N'0800000019',N'demo19@example.test',N'ที่อยู่สมมติ 19','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (20,N'ลูกค้าทดสอบ 020','1985-01-01',N'DEMO-ID-020',N'DEMO-LIC-020','2035-12-31',N'0800000020',N'demo20@example.test',N'ที่อยู่สมมติ 20','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (21,N'ลูกค้าทดสอบ 021','1985-01-01',N'DEMO-ID-021',N'DEMO-LIC-021','2035-12-31',N'0800000021',N'demo21@example.test',N'ที่อยู่สมมติ 21','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (22,N'ลูกค้าทดสอบ 022','1985-01-01',N'DEMO-ID-022',N'DEMO-LIC-022','2035-12-31',N'0800000022',N'demo22@example.test',N'ที่อยู่สมมติ 22','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (23,N'ลูกค้าทดสอบ 023','1985-01-01',N'DEMO-ID-023',N'DEMO-LIC-023','2035-12-31',N'0800000023',N'demo23@example.test',N'ที่อยู่สมมติ 23','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (24,N'ลูกค้าทดสอบ 024','1985-01-01',N'DEMO-ID-024',N'DEMO-LIC-024','2035-12-31',N'0800000024',N'demo24@example.test',N'ที่อยู่สมมติ 24','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (25,N'ลูกค้าทดสอบ 025','1985-01-01',N'DEMO-ID-025',N'DEMO-LIC-025','2035-12-31',N'0800000025',N'demo25@example.test',N'ที่อยู่สมมติ 25','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (26,N'ลูกค้าทดสอบ 026','1985-01-01',N'DEMO-ID-026',N'DEMO-LIC-026','2035-12-31',N'0800000026',N'demo26@example.test',N'ที่อยู่สมมติ 26','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (27,N'ลูกค้าทดสอบ 027','1985-01-01',N'DEMO-ID-027',N'DEMO-LIC-027','2035-12-31',N'0800000027',N'demo27@example.test',N'ที่อยู่สมมติ 27','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (28,N'ลูกค้าทดสอบ 028','1985-01-01',N'DEMO-ID-028',N'DEMO-LIC-028','2035-12-31',N'0800000028',N'demo28@example.test',N'ที่อยู่สมมติ 28','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (29,N'ลูกค้าทดสอบ 029','1985-01-01',N'DEMO-ID-029',N'DEMO-LIC-029','2035-12-31',N'0800000029',N'demo29@example.test',N'ที่อยู่สมมติ 29','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (30,N'ลูกค้าทดสอบ 030','1985-01-01',N'DEMO-ID-030',N'DEMO-LIC-030','2035-12-31',N'0800000030',N'demo30@example.test',N'ที่อยู่สมมติ 30','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (31,N'ลูกค้าทดสอบ 031','1985-01-01',N'DEMO-ID-031',N'DEMO-LIC-031','2035-12-31',N'0800000031',N'demo31@example.test',N'ที่อยู่สมมติ 31','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (32,N'ลูกค้าทดสอบ 032','1985-01-01',N'DEMO-ID-032',N'DEMO-LIC-032','2035-12-31',N'0800000032',N'demo32@example.test',N'ที่อยู่สมมติ 32','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (33,N'ลูกค้าทดสอบ 033','1985-01-01',N'DEMO-ID-033',N'DEMO-LIC-033','2035-12-31',N'0800000033',N'demo33@example.test',N'ที่อยู่สมมติ 33','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (34,N'ลูกค้าทดสอบ 034','1985-01-01',N'DEMO-ID-034',N'DEMO-LIC-034','2035-12-31',N'0800000034',N'demo34@example.test',N'ที่อยู่สมมติ 34','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (35,N'ลูกค้าทดสอบ 035','1985-01-01',N'DEMO-ID-035',N'DEMO-LIC-035','2035-12-31',N'0800000035',N'demo35@example.test',N'ที่อยู่สมมติ 35','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (36,N'ลูกค้าทดสอบ 036','1985-01-01',N'DEMO-ID-036',N'DEMO-LIC-036','2035-12-31',N'0800000036',N'demo36@example.test',N'ที่อยู่สมมติ 36','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (37,N'ลูกค้าทดสอบ 037','1985-01-01',N'DEMO-ID-037',N'DEMO-LIC-037','2035-12-31',N'0800000037',N'demo37@example.test',N'ที่อยู่สมมติ 37','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (38,N'ลูกค้าทดสอบ 038','1985-01-01',N'DEMO-ID-038',N'DEMO-LIC-038','2035-12-31',N'0800000038',N'demo38@example.test',N'ที่อยู่สมมติ 38','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (39,N'ลูกค้าทดสอบ 039','1985-01-01',N'DEMO-ID-039',N'DEMO-LIC-039','2035-12-31',N'0800000039',N'demo39@example.test',N'ที่อยู่สมมติ 39','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (40,N'ลูกค้าทดสอบ 040','1985-01-01',N'DEMO-ID-040',N'DEMO-LIC-040','2035-12-31',N'0800000040',N'demo40@example.test',N'ที่อยู่สมมติ 40','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (41,N'ลูกค้าทดสอบ 041','1985-01-01',N'DEMO-ID-041',N'DEMO-LIC-041','2035-12-31',N'0800000041',N'demo41@example.test',N'ที่อยู่สมมติ 41','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (42,N'ลูกค้าทดสอบ 042','1985-01-01',N'DEMO-ID-042',N'DEMO-LIC-042','2035-12-31',N'0800000042',N'demo42@example.test',N'ที่อยู่สมมติ 42','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (43,N'ลูกค้าทดสอบ 043','1985-01-01',N'DEMO-ID-043',N'DEMO-LIC-043','2035-12-31',N'0800000043',N'demo43@example.test',N'ที่อยู่สมมติ 43','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (44,N'ลูกค้าทดสอบ 044','1985-01-01',N'DEMO-ID-044',N'DEMO-LIC-044','2035-12-31',N'0800000044',N'demo44@example.test',N'ที่อยู่สมมติ 44','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (45,N'ลูกค้าทดสอบ 045','1985-01-01',N'DEMO-ID-045',N'DEMO-LIC-045','2035-12-31',N'0800000045',N'demo45@example.test',N'ที่อยู่สมมติ 45','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (46,N'ลูกค้าทดสอบ 046','1985-01-01',N'DEMO-ID-046',N'DEMO-LIC-046','2035-12-31',N'0800000046',N'demo46@example.test',N'ที่อยู่สมมติ 46','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (47,N'ลูกค้าทดสอบ 047','1985-01-01',N'DEMO-ID-047',N'DEMO-LIC-047','2035-12-31',N'0800000047',N'demo47@example.test',N'ที่อยู่สมมติ 47','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (48,N'ลูกค้าทดสอบ 048','1985-01-01',N'DEMO-ID-048',N'DEMO-LIC-048','2035-12-31',N'0800000048',N'demo48@example.test',N'ที่อยู่สมมติ 48','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (49,N'ลูกค้าทดสอบ 049','1985-01-01',N'DEMO-ID-049',N'DEMO-LIC-049','2035-12-31',N'0800000049',N'demo49@example.test',N'ที่อยู่สมมติ 49','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (50,N'ลูกค้าทดสอบ 050','1985-01-01',N'DEMO-ID-050',N'DEMO-LIC-050','2035-12-31',N'0800000050',N'demo50@example.test',N'ที่อยู่สมมติ 50','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (51,N'ลูกค้าทดสอบ 051','1985-01-01',N'DEMO-ID-051',N'DEMO-LIC-051','2035-12-31',N'0800000051',N'demo51@example.test',N'ที่อยู่สมมติ 51','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (52,N'ลูกค้าทดสอบ 052','1985-01-01',N'DEMO-ID-052',N'DEMO-LIC-052','2035-12-31',N'0800000052',N'demo52@example.test',N'ที่อยู่สมมติ 52','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (53,N'ลูกค้าทดสอบ 053','1985-01-01',N'DEMO-ID-053',N'DEMO-LIC-053','2035-12-31',N'0800000053',N'demo53@example.test',N'ที่อยู่สมมติ 53','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (54,N'ลูกค้าทดสอบ 054','1985-01-01',N'DEMO-ID-054',N'DEMO-LIC-054','2035-12-31',N'0800000054',N'demo54@example.test',N'ที่อยู่สมมติ 54','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (55,N'ลูกค้าทดสอบ 055','1985-01-01',N'DEMO-ID-055',N'DEMO-LIC-055','2035-12-31',N'0800000055',N'demo55@example.test',N'ที่อยู่สมมติ 55','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (56,N'ลูกค้าทดสอบ 056','1985-01-01',N'DEMO-ID-056',N'DEMO-LIC-056','2035-12-31',N'0800000056',N'demo56@example.test',N'ที่อยู่สมมติ 56','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (57,N'ลูกค้าทดสอบ 057','1985-01-01',N'DEMO-ID-057',N'DEMO-LIC-057','2035-12-31',N'0800000057',N'demo57@example.test',N'ที่อยู่สมมติ 57','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (58,N'ลูกค้าทดสอบ 058','1985-01-01',N'DEMO-ID-058',N'DEMO-LIC-058','2035-12-31',N'0800000058',N'demo58@example.test',N'ที่อยู่สมมติ 58','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (59,N'ลูกค้าทดสอบ 059','1985-01-01',N'DEMO-ID-059',N'DEMO-LIC-059','2035-12-31',N'0800000059',N'demo59@example.test',N'ที่อยู่สมมติ 59','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (60,N'ลูกค้าทดสอบ 060','1985-01-01',N'DEMO-ID-060',N'DEMO-LIC-060','2035-12-31',N'0800000060',N'demo60@example.test',N'ที่อยู่สมมติ 60','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (61,N'ลูกค้าทดสอบ 061','1985-01-01',N'DEMO-ID-061',N'DEMO-LIC-061','2035-12-31',N'0800000061',N'demo61@example.test',N'ที่อยู่สมมติ 61','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (62,N'ลูกค้าทดสอบ 062','1985-01-01',N'DEMO-ID-062',N'DEMO-LIC-062','2035-12-31',N'0800000062',N'demo62@example.test',N'ที่อยู่สมมติ 62','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (63,N'ลูกค้าทดสอบ 063','1985-01-01',N'DEMO-ID-063',N'DEMO-LIC-063','2035-12-31',N'0800000063',N'demo63@example.test',N'ที่อยู่สมมติ 63','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (64,N'ลูกค้าทดสอบ 064','1985-01-01',N'DEMO-ID-064',N'DEMO-LIC-064','2035-12-31',N'0800000064',N'demo64@example.test',N'ที่อยู่สมมติ 64','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (65,N'ลูกค้าทดสอบ 065','1985-01-01',N'DEMO-ID-065',N'DEMO-LIC-065','2035-12-31',N'0800000065',N'demo65@example.test',N'ที่อยู่สมมติ 65','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (66,N'ลูกค้าทดสอบ 066','1985-01-01',N'DEMO-ID-066',N'DEMO-LIC-066','2035-12-31',N'0800000066',N'demo66@example.test',N'ที่อยู่สมมติ 66','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (67,N'ลูกค้าทดสอบ 067','1985-01-01',N'DEMO-ID-067',N'DEMO-LIC-067','2035-12-31',N'0800000067',N'demo67@example.test',N'ที่อยู่สมมติ 67','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (68,N'ลูกค้าทดสอบ 068','1985-01-01',N'DEMO-ID-068',N'DEMO-LIC-068','2035-12-31',N'0800000068',N'demo68@example.test',N'ที่อยู่สมมติ 68','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (69,N'ลูกค้าทดสอบ 069','1985-01-01',N'DEMO-ID-069',N'DEMO-LIC-069','2035-12-31',N'0800000069',N'demo69@example.test',N'ที่อยู่สมมติ 69','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (70,N'ลูกค้าทดสอบ 070','1985-01-01',N'DEMO-ID-070',N'DEMO-LIC-070','2035-12-31',N'0800000070',N'demo70@example.test',N'ที่อยู่สมมติ 70','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (71,N'ลูกค้าทดสอบ 071','1985-01-01',N'DEMO-ID-071',N'DEMO-LIC-071','2035-12-31',N'0800000071',N'demo71@example.test',N'ที่อยู่สมมติ 71','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (72,N'ลูกค้าทดสอบ 072','1985-01-01',N'DEMO-ID-072',N'DEMO-LIC-072','2035-12-31',N'0800000072',N'demo72@example.test',N'ที่อยู่สมมติ 72','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (73,N'ลูกค้าทดสอบ 073','1985-01-01',N'DEMO-ID-073',N'DEMO-LIC-073','2035-12-31',N'0800000073',N'demo73@example.test',N'ที่อยู่สมมติ 73','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (74,N'ลูกค้าทดสอบ 074','1985-01-01',N'DEMO-ID-074',N'DEMO-LIC-074','2035-12-31',N'0800000074',N'demo74@example.test',N'ที่อยู่สมมติ 74','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (75,N'ลูกค้าทดสอบ 075','1985-01-01',N'DEMO-ID-075',N'DEMO-LIC-075','2035-12-31',N'0800000075',N'demo75@example.test',N'ที่อยู่สมมติ 75','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (76,N'ลูกค้าทดสอบ 076','1985-01-01',N'DEMO-ID-076',N'DEMO-LIC-076','2035-12-31',N'0800000076',N'demo76@example.test',N'ที่อยู่สมมติ 76','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (77,N'ลูกค้าทดสอบ 077','1985-01-01',N'DEMO-ID-077',N'DEMO-LIC-077','2035-12-31',N'0800000077',N'demo77@example.test',N'ที่อยู่สมมติ 77','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (78,N'ลูกค้าทดสอบ 078','1985-01-01',N'DEMO-ID-078',N'DEMO-LIC-078','2035-12-31',N'0800000078',N'demo78@example.test',N'ที่อยู่สมมติ 78','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (79,N'ลูกค้าทดสอบ 079','1985-01-01',N'DEMO-ID-079',N'DEMO-LIC-079','2035-12-31',N'0800000079',N'demo79@example.test',N'ที่อยู่สมมติ 79','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (80,N'ลูกค้าทดสอบ 080','1985-01-01',N'DEMO-ID-080',N'DEMO-LIC-080','2035-12-31',N'0800000080',N'demo80@example.test',N'ที่อยู่สมมติ 80','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (81,N'ลูกค้าทดสอบ 081','1985-01-01',N'DEMO-ID-081',N'DEMO-LIC-081','2035-12-31',N'0800000081',N'demo81@example.test',N'ที่อยู่สมมติ 81','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (82,N'ลูกค้าทดสอบ 082','1985-01-01',N'DEMO-ID-082',N'DEMO-LIC-082','2035-12-31',N'0800000082',N'demo82@example.test',N'ที่อยู่สมมติ 82','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (83,N'ลูกค้าทดสอบ 083','1985-01-01',N'DEMO-ID-083',N'DEMO-LIC-083','2035-12-31',N'0800000083',N'demo83@example.test',N'ที่อยู่สมมติ 83','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (84,N'ลูกค้าทดสอบ 084','1985-01-01',N'DEMO-ID-084',N'DEMO-LIC-084','2035-12-31',N'0800000084',N'demo84@example.test',N'ที่อยู่สมมติ 84','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (85,N'ลูกค้าทดสอบ 085','1985-01-01',N'DEMO-ID-085',N'DEMO-LIC-085','2035-12-31',N'0800000085',N'demo85@example.test',N'ที่อยู่สมมติ 85','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (86,N'ลูกค้าทดสอบ 086','1985-01-01',N'DEMO-ID-086',N'DEMO-LIC-086','2035-12-31',N'0800000086',N'demo86@example.test',N'ที่อยู่สมมติ 86','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (87,N'ลูกค้าทดสอบ 087','1985-01-01',N'DEMO-ID-087',N'DEMO-LIC-087','2035-12-31',N'0800000087',N'demo87@example.test',N'ที่อยู่สมมติ 87','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (88,N'ลูกค้าทดสอบ 088','1985-01-01',N'DEMO-ID-088',N'DEMO-LIC-088','2035-12-31',N'0800000088',N'demo88@example.test',N'ที่อยู่สมมติ 88','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (89,N'ลูกค้าทดสอบ 089','1985-01-01',N'DEMO-ID-089',N'DEMO-LIC-089','2035-12-31',N'0800000089',N'demo89@example.test',N'ที่อยู่สมมติ 89','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (90,N'ลูกค้าทดสอบ 090','1985-01-01',N'DEMO-ID-090',N'DEMO-LIC-090','2035-12-31',N'0800000090',N'demo90@example.test',N'ที่อยู่สมมติ 90','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (91,N'ลูกค้าทดสอบ 091','1985-01-01',N'DEMO-ID-091',N'DEMO-LIC-091','2035-12-31',N'0800000091',N'demo91@example.test',N'ที่อยู่สมมติ 91','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (92,N'ลูกค้าทดสอบ 092','1985-01-01',N'DEMO-ID-092',N'DEMO-LIC-092','2035-12-31',N'0800000092',N'demo92@example.test',N'ที่อยู่สมมติ 92','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (93,N'ลูกค้าทดสอบ 093','1985-01-01',N'DEMO-ID-093',N'DEMO-LIC-093','2035-12-31',N'0800000093',N'demo93@example.test',N'ที่อยู่สมมติ 93','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (94,N'ลูกค้าทดสอบ 094','1985-01-01',N'DEMO-ID-094',N'DEMO-LIC-094','2035-12-31',N'0800000094',N'demo94@example.test',N'ที่อยู่สมมติ 94','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (95,N'ลูกค้าทดสอบ 095','1985-01-01',N'DEMO-ID-095',N'DEMO-LIC-095','2035-12-31',N'0800000095',N'demo95@example.test',N'ที่อยู่สมมติ 95','ACTIVE');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (96,N'ลูกค้าทดสอบ 096','1985-01-01',N'DEMO-ID-096',N'DEMO-LIC-096','2035-12-31',N'0800000096',N'demo96@example.test',N'ที่อยู่สมมติ 96','SUSPENDED');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (97,N'ลูกค้าทดสอบ 097','1985-01-01',N'DEMO-ID-097',N'DEMO-LIC-097','2035-12-31',N'0800000097',N'demo97@example.test',N'ที่อยู่สมมติ 97','SUSPENDED');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (98,N'ลูกค้าทดสอบ 098','1985-01-01',N'DEMO-ID-098',N'DEMO-LIC-098','2035-12-31',N'0800000098',N'demo98@example.test',N'ที่อยู่สมมติ 98','SUSPENDED');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (99,N'ลูกค้าทดสอบ 099','1985-01-01',N'DEMO-ID-099',N'DEMO-LIC-099','2035-12-31',N'0800000099',N'demo99@example.test',N'ที่อยู่สมมติ 99','SUSPENDED');
INSERT dbo.customer ([customer_id],[full_name],[birth_date],[identity_document_no],[license_no],[license_expiry_date],[phone],[email],[address],[status]) VALUES (100,N'ลูกค้าทดสอบ 100','1985-01-01',N'DEMO-ID-100',N'DEMO-LIC-100','2035-12-31',N'0800000100',N'demo100@example.test',N'ที่อยู่สมมติ 100','SUSPENDED');
SET IDENTITY_INSERT dbo.customer OFF;
-- รถยนต์ (วีฮิเคิล): 100 รายการ
SET IDENTITY_INSERT dbo.vehicle ON;
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (1,N'ทดสอบ-001',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,900,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (2,N'ทดสอบ-002',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,1000,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (3,N'ทดสอบ-003',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,1100,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (4,N'ทดสอบ-004',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,1200,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (5,N'ทดสอบ-005',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,800,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (6,N'ทดสอบ-006',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,900,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (7,N'ทดสอบ-007',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,1000,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (8,N'ทดสอบ-008',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,1100,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (9,N'ทดสอบ-009',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,1200,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (10,N'ทดสอบ-010',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,800,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (11,N'ทดสอบ-011',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,900,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (12,N'ทดสอบ-012',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,1000,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (13,N'ทดสอบ-013',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,1100,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (14,N'ทดสอบ-014',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,1200,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (15,N'ทดสอบ-015',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,800,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (16,N'ทดสอบ-016',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,900,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (17,N'ทดสอบ-017',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,1000,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (18,N'ทดสอบ-018',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,1100,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (19,N'ทดสอบ-019',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,1200,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (20,N'ทดสอบ-020',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,800,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (21,N'ทดสอบ-021',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,900,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (22,N'ทดสอบ-022',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,1000,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (23,N'ทดสอบ-023',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,1100,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (24,N'ทดสอบ-024',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,1200,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (25,N'ทดสอบ-025',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,800,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (26,N'ทดสอบ-026',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,900,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (27,N'ทดสอบ-027',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,1000,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (28,N'ทดสอบ-028',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,1100,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (29,N'ทดสอบ-029',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,1200,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (30,N'ทดสอบ-030',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,800,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (31,N'ทดสอบ-031',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,900,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (32,N'ทดสอบ-032',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,1000,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (33,N'ทดสอบ-033',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,1100,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (34,N'ทดสอบ-034',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,1200,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (35,N'ทดสอบ-035',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,800,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (36,N'ทดสอบ-036',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,900,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (37,N'ทดสอบ-037',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,1000,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (38,N'ทดสอบ-038',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,1100,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (39,N'ทดสอบ-039',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,1200,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (40,N'ทดสอบ-040',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,800,3000,10000,'RENTED');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (41,N'ทดสอบ-041',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,900,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (42,N'ทดสอบ-042',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,1000,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (43,N'ทดสอบ-043',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,1100,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (44,N'ทดสอบ-044',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,1200,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (45,N'ทดสอบ-045',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,800,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (46,N'ทดสอบ-046',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,900,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (47,N'ทดสอบ-047',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,1000,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (48,N'ทดสอบ-048',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,1100,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (49,N'ทดสอบ-049',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,1200,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (50,N'ทดสอบ-050',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,800,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (51,N'ทดสอบ-051',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,900,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (52,N'ทดสอบ-052',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,1000,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (53,N'ทดสอบ-053',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,1100,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (54,N'ทดสอบ-054',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,1200,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (55,N'ทดสอบ-055',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,800,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (56,N'ทดสอบ-056',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,900,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (57,N'ทดสอบ-057',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,1000,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (58,N'ทดสอบ-058',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,1100,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (59,N'ทดสอบ-059',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,1200,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (60,N'ทดสอบ-060',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,800,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (61,N'ทดสอบ-061',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,900,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (62,N'ทดสอบ-062',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,1000,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (63,N'ทดสอบ-063',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,1100,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (64,N'ทดสอบ-064',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,1200,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (65,N'ทดสอบ-065',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,800,3000,10200,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (66,N'ทดสอบ-066',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,900,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (67,N'ทดสอบ-067',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,1000,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (68,N'ทดสอบ-068',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,1100,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (69,N'ทดสอบ-069',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,1200,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (70,N'ทดสอบ-070',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,800,3000,10200,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (71,N'ทดสอบ-071',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,900,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (72,N'ทดสอบ-072',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,1000,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (73,N'ทดสอบ-073',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,1100,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (74,N'ทดสอบ-074',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,1200,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (75,N'ทดสอบ-075',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,800,3000,10200,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (76,N'ทดสอบ-076',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,900,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (77,N'ทดสอบ-077',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,1000,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (78,N'ทดสอบ-078',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,1100,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (79,N'ทดสอบ-079',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,1200,3000,10200,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (80,N'ทดสอบ-080',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,800,3000,10200,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (81,N'ทดสอบ-081',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,900,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (82,N'ทดสอบ-082',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,1000,3000,10000,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (83,N'ทดสอบ-083',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,1100,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (84,N'ทดสอบ-084',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,1200,3000,10000,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (85,N'ทดสอบ-085',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,800,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (86,N'ทดสอบ-086',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,900,3000,10000,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (87,N'ทดสอบ-087',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,1000,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (88,N'ทดสอบ-088',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,1100,3000,10000,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (89,N'ทดสอบ-089',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,1200,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (90,N'ทดสอบ-090',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,800,3000,10000,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (91,N'ทดสอบ-091',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,900,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (92,N'ทดสอบ-092',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,1000,3000,10000,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (93,N'ทดสอบ-093',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,1100,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (94,N'ทดสอบ-094',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,1200,3000,10000,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (95,N'ทดสอบ-095',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'รถตู้',2024,800,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (96,N'ทดสอบ-096',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'เก๋ง',2024,900,3000,10000,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (97,N'ทดสอบ-097',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'SUV',2024,1000,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (98,N'ทดสอบ-098',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'รถตู้',2024,1100,3000,10000,'MAINTENANCE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (99,N'ทดสอบ-099',N'กรุงเทพมหานคร',N'Toyota',N'Demo Model',N'เก๋ง',2024,1200,3000,10000,'AVAILABLE');
INSERT dbo.vehicle ([vehicle_id],[registration_no],[registration_province],[brand],[model],[vehicle_type],[model_year],[daily_rate],[deposit_amount],[current_mileage],[status]) VALUES (100,N'ทดสอบ-100',N'กรุงเทพมหานคร',N'Honda',N'Demo Model',N'SUV',2024,800,3000,10000,'MAINTENANCE');
SET IDENTITY_INSERT dbo.vehicle OFF;
-- พนักงาน (เอ็มพลอยอี): 4 รายการ
SET IDENTITY_INSERT dbo.employee ON;
INSERT dbo.employee ([employee_id],[employee_code],[full_name],[phone],[role],[status]) VALUES (1,'EMP001',N'พนักงานส่งมอบรถ',N'0800000001','STAFF','ACTIVE');
INSERT dbo.employee ([employee_id],[employee_code],[full_name],[phone],[role],[status]) VALUES (2,'EMP002',N'พนักงานรับคืนรถ',N'0800000002','STAFF','ACTIVE');
INSERT dbo.employee ([employee_id],[employee_code],[full_name],[phone],[role],[status]) VALUES (3,'MGR001',N'ผู้จัดการระบบ',N'0800000003','MANAGER','ACTIVE');
INSERT dbo.employee ([employee_id],[employee_code],[full_name],[phone],[role],[status]) VALUES (4,'EMP004',N'พนักงานพักงาน',N'0800000004','STAFF','INACTIVE');
SET IDENTITY_INSERT dbo.employee OFF;
-- การจอง (เรเซอร์เวชัน): 100 รายการ
SET IDENTITY_INSERT dbo.reservation ON;
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (1,'DEMO-RS-001',1,1,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (2,'DEMO-RS-002',2,2,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (3,'DEMO-RS-003',3,3,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (4,'DEMO-RS-004',4,4,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (5,'DEMO-RS-005',5,5,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (6,'DEMO-RS-006',6,6,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (7,'DEMO-RS-007',7,7,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (8,'DEMO-RS-008',8,8,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (9,'DEMO-RS-009',9,9,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (10,'DEMO-RS-010',10,10,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (11,'DEMO-RS-011',11,11,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (12,'DEMO-RS-012',12,12,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (13,'DEMO-RS-013',13,13,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (14,'DEMO-RS-014',14,14,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (15,'DEMO-RS-015',15,15,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (16,'DEMO-RS-016',16,16,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (17,'DEMO-RS-017',17,17,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (18,'DEMO-RS-018',18,18,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (19,'DEMO-RS-019',19,19,'2026-09-23T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (20,'DEMO-RS-020',20,20,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (21,'DEMO-RS-021',21,21,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (22,'DEMO-RS-022',22,22,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (23,'DEMO-RS-023',23,23,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (24,'DEMO-RS-024',24,24,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (25,'DEMO-RS-025',25,25,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (26,'DEMO-RS-026',26,26,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (27,'DEMO-RS-027',27,27,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (28,'DEMO-RS-028',28,28,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (29,'DEMO-RS-029',29,29,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (30,'DEMO-RS-030',30,30,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (31,'DEMO-RS-031',31,31,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (32,'DEMO-RS-032',32,32,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (33,'DEMO-RS-033',33,33,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (34,'DEMO-RS-034',34,34,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (35,'DEMO-RS-035',35,35,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (36,'DEMO-RS-036',36,36,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (37,'DEMO-RS-037',37,37,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (38,'DEMO-RS-038',38,38,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (39,'DEMO-RS-039',39,39,'2026-10-07T10:00:00','2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (40,'DEMO-RS-040',40,40,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (41,'DEMO-RS-041',41,41,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (42,'DEMO-RS-042',42,42,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (43,'DEMO-RS-043',43,43,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (44,'DEMO-RS-044',44,44,'2026-10-07T10:00:00','2026-10-26T10:00:00','2026-10-28T10:00:00','2026-10-26T13:00:00','CONFIRMED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (45,'DEMO-RS-045',45,45,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (46,'DEMO-RS-046',46,46,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (47,'DEMO-RS-047',47,47,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (48,'DEMO-RS-048',48,48,'2026-10-07T10:00:00','2026-10-26T10:00:00','2026-10-28T10:00:00','2026-10-26T13:00:00','PENDING',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (49,'DEMO-RS-049',49,49,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (50,'DEMO-RS-050',50,50,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (51,'DEMO-RS-051',51,51,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (52,'DEMO-RS-052',52,52,'2026-10-07T10:00:00','2026-10-26T10:00:00','2026-10-28T10:00:00','2026-10-26T13:00:00','CONFIRMED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (53,'DEMO-RS-053',53,53,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (54,'DEMO-RS-054',54,54,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (55,'DEMO-RS-055',55,55,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (56,'DEMO-RS-056',56,56,'2026-10-07T10:00:00','2026-10-26T10:00:00','2026-10-28T10:00:00','2026-10-26T13:00:00','PENDING',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (57,'DEMO-RS-057',57,57,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (58,'DEMO-RS-058',58,58,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (59,'DEMO-RS-059',59,59,'2026-10-13T10:00:00','2026-10-16T10:00:00','2026-10-18T10:00:00','2026-10-16T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (60,'DEMO-RS-060',60,60,'2026-10-07T10:00:00','2026-10-26T10:00:00','2026-10-28T10:00:00','2026-10-26T13:00:00','CONFIRMED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (61,'DEMO-RS-061',61,61,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (62,'DEMO-RS-062',62,62,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (63,'DEMO-RS-063',63,63,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (64,'DEMO-RS-064',64,64,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (65,'DEMO-RS-065',65,65,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (66,'DEMO-RS-066',66,66,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (67,'DEMO-RS-067',67,67,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (68,'DEMO-RS-068',68,68,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (69,'DEMO-RS-069',69,69,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (70,'DEMO-RS-070',70,70,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (71,'DEMO-RS-071',71,71,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (72,'DEMO-RS-072',72,72,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (73,'DEMO-RS-073',73,73,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (74,'DEMO-RS-074',74,74,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (75,'DEMO-RS-075',75,75,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (76,'DEMO-RS-076',76,76,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (77,'DEMO-RS-077',77,77,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (78,'DEMO-RS-078',78,78,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (79,'DEMO-RS-079',79,79,'2026-10-03T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T13:00:00','CONVERTED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (80,'DEMO-RS-080',80,80,'2026-10-07T10:00:00','2026-10-09T10:00:00','2026-10-10T10:00:00','2026-10-10T10:00:00','EXPIRED',NULL,NULL);
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (81,'DEMO-RS-081',81,81,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (82,'DEMO-RS-082',82,82,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (83,'DEMO-RS-083',83,83,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (84,'DEMO-RS-084',84,84,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (85,'DEMO-RS-085',85,85,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (86,'DEMO-RS-086',86,86,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (87,'DEMO-RS-087',87,87,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (88,'DEMO-RS-088',88,88,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (89,'DEMO-RS-089',89,89,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (90,'DEMO-RS-090',90,90,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (91,'DEMO-RS-091',91,91,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (92,'DEMO-RS-092',92,92,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (93,'DEMO-RS-093',93,93,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (94,'DEMO-RS-094',94,94,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (95,'DEMO-RS-095',95,95,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (96,'DEMO-RS-096',96,96,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (97,'DEMO-RS-097',97,97,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (98,'DEMO-RS-098',98,98,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (99,'DEMO-RS-099',99,99,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
INSERT dbo.reservation ([reservation_id],[reservation_no],[customer_id],[vehicle_id],[reserved_at],[pickup_at],[return_at],[expires_at],[status],[cancelled_at],[cancellation_reason]) VALUES (100,'DEMO-RS-100',100,100,'2026-10-18T10:00:00','2026-10-21T10:00:00','2026-10-23T10:00:00','2026-10-21T13:00:00','CANCELLED','2026-10-19T10:00:00',N'ข้อมูลตัวอย่างยกเลิก');
SET IDENTITY_INSERT dbo.reservation OFF;
-- สัญญาเช่า (เรนทัล): 100 รายการ
SET IDENTITY_INSERT dbo.rental ON;
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (1,'DEMO-RT-001',1,1,1,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',900,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (2,'DEMO-RT-002',2,2,2,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1000,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (3,'DEMO-RT-003',3,3,3,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1100,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (4,'DEMO-RT-004',NULL,4,4,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1200,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (5,'DEMO-RT-005',5,5,5,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',800,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (6,'DEMO-RT-006',6,6,6,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',900,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (7,'DEMO-RT-007',7,7,7,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1000,1,200,1000,3000,100,3,'2026-09-25T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (8,'DEMO-RT-008',NULL,8,8,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1100,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (9,'DEMO-RT-009',9,9,9,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1200,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (10,'DEMO-RT-010',10,10,10,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',800,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (11,'DEMO-RT-011',11,11,11,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',900,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (12,'DEMO-RT-012',NULL,12,12,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1000,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (13,'DEMO-RT-013',13,13,13,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1100,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (14,'DEMO-RT-014',14,14,14,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1200,0,0,0,3000,100,3,'2026-09-25T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (15,'DEMO-RT-015',15,15,15,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',800,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (16,'DEMO-RT-016',NULL,16,16,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',900,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (17,'DEMO-RT-017',17,17,17,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1000,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (18,'DEMO-RT-018',18,18,18,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1100,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (19,'DEMO-RT-019',19,19,19,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',1200,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (20,'DEMO-RT-020',NULL,20,20,1,2,'2026-09-26T10:00:00','2026-09-28T10:00:00','2026-09-26T10:00:00','2026-09-28T10:00:00',800,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','CLOSED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (21,'DEMO-RT-021',21,21,21,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,900,1,200,1000,3000,100,3,'2026-10-09T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (22,'DEMO-RT-022',22,22,22,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1000,0,0,0,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (23,'DEMO-RT-023',23,23,23,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1100,1,200,1000,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (24,'DEMO-RT-024',NULL,24,24,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1200,0,0,0,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (25,'DEMO-RT-025',25,25,25,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,800,1,200,1000,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (26,'DEMO-RT-026',26,26,26,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,900,0,0,0,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (27,'DEMO-RT-027',27,27,27,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1000,1,200,1000,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (28,'DEMO-RT-028',NULL,28,28,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1100,0,0,0,3000,100,3,'2026-10-09T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (29,'DEMO-RT-029',29,29,29,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1200,1,200,1000,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (30,'DEMO-RT-030',30,30,30,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,800,0,0,0,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (31,'DEMO-RT-031',31,31,31,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,900,1,200,1000,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (32,'DEMO-RT-032',NULL,32,32,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1000,0,0,0,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (33,'DEMO-RT-033',33,33,33,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1100,1,200,1000,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (34,'DEMO-RT-034',34,34,34,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1200,0,0,0,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (35,'DEMO-RT-035',35,35,35,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,800,1,200,1000,3000,100,3,'2026-10-09T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (36,'DEMO-RT-036',NULL,36,36,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,900,0,0,0,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (37,'DEMO-RT-037',37,37,37,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1000,1,200,1000,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (38,'DEMO-RT-038',38,38,38,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1100,0,0,0,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (39,'DEMO-RT-039',39,39,39,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,1200,1,200,1000,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (40,'DEMO-RT-040',NULL,40,40,1,NULL,'2026-10-10T10:00:00','2026-10-13T10:00:00','2026-10-10T10:00:00',NULL,800,0,0,0,3000,0,NULL,NULL,NULL,10000,NULL,100,NULL,N'สภาพปกติตอนรับ',NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (41,'DEMO-RT-041',41,41,41,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,900,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (42,'DEMO-RT-042',42,42,42,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1000,0,0,0,3000,100,3,'2026-10-15T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (43,'DEMO-RT-043',43,43,43,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1100,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (44,'DEMO-RT-044',NULL,44,44,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1200,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (45,'DEMO-RT-045',45,45,45,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,800,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (46,'DEMO-RT-046',46,46,46,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,900,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (47,'DEMO-RT-047',47,47,47,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1000,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (48,'DEMO-RT-048',NULL,48,48,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1100,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (49,'DEMO-RT-049',49,49,49,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1200,1,200,1000,3000,100,3,'2026-10-15T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (50,'DEMO-RT-050',50,50,50,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,800,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (51,'DEMO-RT-051',51,51,51,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,900,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (52,'DEMO-RT-052',NULL,52,52,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1000,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (53,'DEMO-RT-053',53,53,53,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1100,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (54,'DEMO-RT-054',54,54,54,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1200,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (55,'DEMO-RT-055',55,55,55,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,800,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (56,'DEMO-RT-056',NULL,56,56,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,900,0,0,0,3000,100,3,'2026-10-15T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (57,'DEMO-RT-057',57,57,57,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1000,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (58,'DEMO-RT-058',58,58,58,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1100,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (59,'DEMO-RT-059',59,59,59,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,1200,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (60,'DEMO-RT-060',NULL,60,60,1,NULL,'2026-10-16T10:00:00','2026-10-18T10:00:00',NULL,NULL,800,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (61,'DEMO-RT-061',61,61,61,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',900,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (62,'DEMO-RT-062',62,62,62,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1000,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (63,'DEMO-RT-063',63,63,63,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1100,1,200,1000,3000,100,3,'2026-10-05T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (64,'DEMO-RT-064',NULL,64,64,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1200,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (65,'DEMO-RT-065',65,65,65,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',800,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (66,'DEMO-RT-066',66,66,66,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',900,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (67,'DEMO-RT-067',67,67,67,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1000,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (68,'DEMO-RT-068',NULL,68,68,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1100,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (69,'DEMO-RT-069',69,69,69,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1200,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (70,'DEMO-RT-070',70,70,70,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',800,0,0,0,3000,100,3,'2026-10-05T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (71,'DEMO-RT-071',71,71,71,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',900,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (72,'DEMO-RT-072',NULL,72,72,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1000,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (73,'DEMO-RT-073',73,73,73,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1100,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (74,'DEMO-RT-074',74,74,74,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1200,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (75,'DEMO-RT-075',75,75,75,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',800,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (76,'DEMO-RT-076',NULL,76,76,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',900,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (77,'DEMO-RT-077',77,77,77,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1000,1,200,1000,3000,100,3,'2026-10-05T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (78,'DEMO-RT-078',78,78,78,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1100,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (79,'DEMO-RT-079',79,79,79,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',1200,1,200,1000,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (80,'DEMO-RT-080',NULL,80,80,1,2,'2026-10-06T10:00:00','2026-10-08T10:00:00','2026-10-06T10:00:00','2026-10-08T10:00:00',800,0,0,0,3000,0,NULL,NULL,NULL,10000,10200,100,100,N'สภาพปกติตอนรับ',N'ตรวจสภาพแล้ว','OPEN');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (81,'DEMO-RT-081',81,81,81,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,900,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (82,'DEMO-RT-082',82,82,82,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1000,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (83,'DEMO-RT-083',83,83,83,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1100,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (84,'DEMO-RT-084',NULL,84,84,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1200,0,0,0,3000,100,3,'2026-10-20T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (85,'DEMO-RT-085',85,85,85,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,800,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (86,'DEMO-RT-086',86,86,86,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,900,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (87,'DEMO-RT-087',87,87,87,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1000,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (88,'DEMO-RT-088',NULL,88,88,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1100,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (89,'DEMO-RT-089',89,89,89,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1200,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (90,'DEMO-RT-090',90,90,90,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,800,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (91,'DEMO-RT-091',91,91,91,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,900,1,200,1000,3000,100,3,'2026-10-20T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (92,'DEMO-RT-092',NULL,92,92,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1000,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (93,'DEMO-RT-093',93,93,93,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1100,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (94,'DEMO-RT-094',94,94,94,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1200,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (95,'DEMO-RT-095',95,95,95,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,800,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (96,'DEMO-RT-096',NULL,96,96,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,900,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (97,'DEMO-RT-097',97,97,97,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1000,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (98,'DEMO-RT-098',98,98,98,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1100,0,0,0,3000,100,3,'2026-10-20T10:00:00',N'ส่วนลดตัวอย่างโดยผู้จัดการ',NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (99,'DEMO-RT-099',99,99,99,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,1200,1,200,1000,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
INSERT dbo.rental ([rental_id],[rental_no],[reservation_id],[customer_id],[vehicle_id],[pickup_employee_id],[return_employee_id],[pickup_at],[due_return_at],[actual_pickup_at],[actual_return_at],[agreed_daily_rate],[insurance_selected],[insurance_fee],[deductible_amount],[required_deposit],[discount_amount],[discount_approved_by],[discount_approved_at],[discount_reason],[pickup_mileage],[return_mileage],[pickup_fuel_percent],[return_fuel_percent],[pickup_condition],[return_condition],[status]) VALUES (100,'DEMO-RT-100',NULL,100,100,1,NULL,'2026-10-21T10:00:00','2026-10-23T10:00:00',NULL,NULL,800,0,0,0,3000,0,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,'CANCELLED');
SET IDENTITY_INSERT dbo.rental OFF;
-- การชำระเงิน (เพย์เมนต์): 176 รายการ
SET IDENTITY_INSERT dbo.payment ON;
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (1,1,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-1','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (2,1,1,'RENTAL',2000,'TRANSFER',N'DEMO-PAY-1','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (3,1,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (4,1,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (5,2,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-2','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (6,2,1,'RENTAL',2000,'TRANSFER',N'DEMO-PAY-2','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (7,2,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (8,2,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (9,3,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-3','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (10,3,1,'RENTAL',2400,'TRANSFER',N'DEMO-PAY-3','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (11,3,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (12,3,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (13,4,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-4','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (14,4,1,'RENTAL',2400,'TRANSFER',N'DEMO-PAY-4','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (15,4,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (16,4,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (17,5,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-5','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (18,5,1,'RENTAL',1800,'TRANSFER',N'DEMO-PAY-5','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (19,5,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (20,6,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-6','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (21,6,1,'RENTAL',1800,'TRANSFER',N'DEMO-PAY-6','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (22,6,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (23,6,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (24,7,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-7','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (25,7,1,'RENTAL',2100,'TRANSFER',N'DEMO-PAY-7','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (26,7,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (27,7,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (28,8,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-8','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (29,8,1,'RENTAL',2200,'TRANSFER',N'DEMO-PAY-8','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (30,8,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (31,8,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (32,9,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-9','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (33,9,1,'RENTAL',2600,'TRANSFER',N'DEMO-PAY-9','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (34,9,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (35,9,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (36,10,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-10','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (37,10,1,'RENTAL',1600,'TRANSFER',N'DEMO-PAY-10','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (38,10,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (39,11,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-11','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (40,11,1,'RENTAL',2000,'TRANSFER',N'DEMO-PAY-11','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (41,11,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (42,11,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (43,12,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-12','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (44,12,1,'RENTAL',2000,'TRANSFER',N'DEMO-PAY-12','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (45,12,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (46,12,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (47,13,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-13','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (48,13,1,'RENTAL',2400,'TRANSFER',N'DEMO-PAY-13','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (49,13,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (50,13,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (51,14,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-14','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (52,14,1,'RENTAL',2300,'TRANSFER',N'DEMO-PAY-14','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (53,14,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (54,14,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (55,15,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-15','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (56,15,1,'RENTAL',1800,'TRANSFER',N'DEMO-PAY-15','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (57,15,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (58,16,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-16','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (59,16,1,'RENTAL',1800,'TRANSFER',N'DEMO-PAY-16','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (60,16,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (61,16,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (62,17,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-17','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (63,17,1,'RENTAL',2200,'TRANSFER',N'DEMO-PAY-17','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (64,17,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (65,17,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (66,18,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-18','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (67,18,1,'RENTAL',2200,'TRANSFER',N'DEMO-PAY-18','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (68,18,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (69,18,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (70,19,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-19','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (71,19,1,'RENTAL',2600,'TRANSFER',N'DEMO-PAY-19','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (72,19,2,'FINE',100,'CARD',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (73,19,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (74,20,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-20','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (75,20,1,'RENTAL',1600,'TRANSFER',N'DEMO-PAY-20','2026-09-26T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (76,20,2,'DEPOSIT_REFUND',3000,'TRANSFER',NULL,'2026-09-28T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (77,21,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-21','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (78,21,1,'RENTAL',2800,'TRANSFER',N'DEMO-PAY-21','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (79,22,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-22','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (80,22,1,'RENTAL',3000,'TRANSFER',N'DEMO-PAY-22','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (81,23,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-23','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (82,23,1,'RENTAL',3500,'TRANSFER',N'DEMO-PAY-23','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (83,24,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-24','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (84,24,1,'RENTAL',3600,'TRANSFER',N'DEMO-PAY-24','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (85,25,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-25','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (86,25,1,'RENTAL',2600,'TRANSFER',N'DEMO-PAY-25','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (87,26,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-26','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (88,26,1,'RENTAL',2700,'TRANSFER',N'DEMO-PAY-26','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (89,27,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-27','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (90,27,1,'RENTAL',3200,'TRANSFER',N'DEMO-PAY-27','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (91,28,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-28','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (92,28,1,'RENTAL',3200,'TRANSFER',N'DEMO-PAY-28','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (93,29,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-29','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (94,29,1,'RENTAL',3800,'TRANSFER',N'DEMO-PAY-29','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (95,30,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-30','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (96,30,1,'RENTAL',2400,'TRANSFER',N'DEMO-PAY-30','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (97,31,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-31','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (98,31,1,'RENTAL',2900,'TRANSFER',N'DEMO-PAY-31','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (99,32,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-32','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (100,32,1,'RENTAL',3000,'TRANSFER',N'DEMO-PAY-32','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (101,33,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-33','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (102,33,1,'RENTAL',3500,'TRANSFER',N'DEMO-PAY-33','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (103,34,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-34','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (104,34,1,'RENTAL',3600,'TRANSFER',N'DEMO-PAY-34','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (105,35,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-35','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (106,35,1,'RENTAL',2500,'TRANSFER',N'DEMO-PAY-35','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (107,36,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-36','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (108,36,1,'RENTAL',2700,'TRANSFER',N'DEMO-PAY-36','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (109,37,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-37','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (110,37,1,'RENTAL',3200,'TRANSFER',N'DEMO-PAY-37','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (111,38,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-38','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (112,38,1,'RENTAL',3300,'TRANSFER',N'DEMO-PAY-38','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (113,39,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-39','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (114,39,1,'RENTAL',3800,'TRANSFER',N'DEMO-PAY-39','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (115,40,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-40','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (116,40,1,'RENTAL',2400,'TRANSFER',N'DEMO-PAY-40','2026-10-10T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (117,41,1,'DEPOSIT',3000,'CARD',NULL,'2026-10-11T10:00:00','CANCELLED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (118,42,1,'DEPOSIT',3000,'CASH',NULL,'2026-10-11T10:00:00','PENDING',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (119,43,1,'DEPOSIT',3000,'TRANSFER',NULL,'2026-10-11T10:00:00','FAILED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (120,44,1,'DEPOSIT',3000,'CARD',NULL,'2026-10-11T10:00:00','CANCELLED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (121,45,1,'DEPOSIT',3000,'CASH',NULL,'2026-10-11T10:00:00','PENDING',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (122,46,1,'DEPOSIT',3000,'TRANSFER',NULL,'2026-10-11T10:00:00','FAILED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (123,47,1,'DEPOSIT',3000,'CARD',NULL,'2026-10-11T10:00:00','CANCELLED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (124,48,1,'DEPOSIT',3000,'CASH',NULL,'2026-10-11T10:00:00','PENDING',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (125,49,1,'DEPOSIT',3000,'TRANSFER',NULL,'2026-10-11T10:00:00','FAILED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (126,50,1,'DEPOSIT',3000,'CARD',NULL,'2026-10-11T10:00:00','CANCELLED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (127,51,1,'DEPOSIT',3000,'CASH',NULL,'2026-10-11T10:00:00','PENDING',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (128,52,1,'DEPOSIT',3000,'TRANSFER',NULL,'2026-10-11T10:00:00','FAILED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (129,53,1,'DEPOSIT',3000,'CARD',NULL,'2026-10-11T10:00:00','CANCELLED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (130,54,1,'DEPOSIT',3000,'CASH',NULL,'2026-10-11T10:00:00','PENDING',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (131,55,1,'DEPOSIT',3000,'TRANSFER',NULL,'2026-10-11T10:00:00','FAILED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (132,56,1,'DEPOSIT',3000,'CARD',NULL,'2026-10-11T10:00:00','CANCELLED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (133,57,1,'DEPOSIT',3000,'CASH',NULL,'2026-10-11T10:00:00','PENDING',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (134,58,1,'DEPOSIT',3000,'TRANSFER',NULL,'2026-10-11T10:00:00','FAILED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (135,59,1,'DEPOSIT',3000,'CARD',NULL,'2026-10-11T10:00:00','CANCELLED',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (136,60,1,'DEPOSIT',3000,'CASH',NULL,'2026-10-11T10:00:00','PENDING',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (137,61,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-61','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (138,61,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (139,62,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-62','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (140,62,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (141,63,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-63','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (142,63,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (143,64,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-64','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (144,64,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (145,65,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-65','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (146,65,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (147,66,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-66','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (148,66,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (149,67,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-67','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (150,67,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (151,68,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-68','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (152,68,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (153,69,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-69','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (154,69,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (155,70,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-70','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (156,70,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (157,71,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-71','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (158,71,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (159,72,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-72','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (160,72,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (161,73,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-73','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (162,73,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (163,74,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-74','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (164,74,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (165,75,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-75','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (166,75,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (167,76,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-76','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (168,76,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (169,77,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-77','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (170,77,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (171,78,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-78','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (172,78,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (173,79,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-79','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (174,79,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (175,80,1,'DEPOSIT',3000,'CASH',N'DEMO-DEP-80','2026-10-06T10:00:00','SUCCESS',NULL);
INSERT dbo.payment ([payment_id],[rental_id],[employee_id],[payment_type],[amount],[payment_method],[reference_no],[paid_at],[status],[notes]) VALUES (176,80,2,'RENTAL',500,'DEPOSIT',NULL,'2026-10-08T10:00:00','SUCCESS',N'นำเงินประกันไปชำระส่วนหนึ่ง');
SET IDENTITY_INSERT dbo.payment OFF;
-- ค่าปรับและความเสียหาย (ไฟน์ / แดเมจ): 40 รายการ
SET IDENTITY_INSERT dbo.fine_damage ON;
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (1,1,2,'FUEL',N'ค่าปรับสมมติ 1',N'https://example.test/evidence/1.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (2,2,2,'EXCESS_MILEAGE',N'ค่าปรับสมมติ 2',N'https://example.test/evidence/2.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (3,3,2,'TRAFFIC',N'ค่าปรับสมมติ 3',N'https://example.test/evidence/3.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (4,4,2,'DAMAGE',N'ค่าปรับสมมติ 4',N'https://example.test/evidence/4.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (5,5,2,'LATE_RETURN',N'ค่าปรับสมมติ 5',N'https://example.test/evidence/5.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','WAIVED',3,'2026-09-28T10:00:00',N'ยกเว้นตัวอย่าง');
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (6,6,2,'FUEL',N'ค่าปรับสมมติ 6',N'https://example.test/evidence/6.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (7,7,2,'EXCESS_MILEAGE',N'ค่าปรับสมมติ 7',N'https://example.test/evidence/7.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (8,8,2,'TRAFFIC',N'ค่าปรับสมมติ 8',N'https://example.test/evidence/8.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (9,9,2,'DAMAGE',N'ค่าปรับสมมติ 9',N'https://example.test/evidence/9.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (10,10,2,'LATE_RETURN',N'ค่าปรับสมมติ 10',N'https://example.test/evidence/10.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','WAIVED',3,'2026-09-28T10:00:00',N'ยกเว้นตัวอย่าง');
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (11,11,2,'FUEL',N'ค่าปรับสมมติ 11',N'https://example.test/evidence/11.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (12,12,2,'EXCESS_MILEAGE',N'ค่าปรับสมมติ 12',N'https://example.test/evidence/12.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (13,13,2,'TRAFFIC',N'ค่าปรับสมมติ 13',N'https://example.test/evidence/13.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (14,14,2,'DAMAGE',N'ค่าปรับสมมติ 14',N'https://example.test/evidence/14.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (15,15,2,'LATE_RETURN',N'ค่าปรับสมมติ 15',N'https://example.test/evidence/15.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','WAIVED',3,'2026-09-28T10:00:00',N'ยกเว้นตัวอย่าง');
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (16,16,2,'FUEL',N'ค่าปรับสมมติ 16',N'https://example.test/evidence/16.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (17,17,2,'EXCESS_MILEAGE',N'ค่าปรับสมมติ 17',N'https://example.test/evidence/17.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (18,18,2,'TRAFFIC',N'ค่าปรับสมมติ 18',N'https://example.test/evidence/18.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (19,19,2,'DAMAGE',N'ค่าปรับสมมติ 19',N'https://example.test/evidence/19.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','PAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (20,20,2,'LATE_RETURN',N'ค่าปรับสมมติ 20',N'https://example.test/evidence/20.jpg',100,100,'2026-09-28T10:00:00','2026-10-05T10:00:00','WAIVED',3,'2026-09-28T10:00:00',N'ยกเว้นตัวอย่าง');
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (21,61,2,'FUEL',N'ค่าปรับค้างตัวอย่าง 61',N'https://example.test/evidence/61.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (22,62,2,'EXCESS_MILEAGE',N'ค่าปรับค้างตัวอย่าง 62',N'https://example.test/evidence/62.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (23,63,2,'TRAFFIC',N'ค่าปรับค้างตัวอย่าง 63',N'https://example.test/evidence/63.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (24,64,2,'DAMAGE',N'ค่าปรับค้างตัวอย่าง 64',N'https://example.test/evidence/64.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (25,65,2,'LATE_RETURN',N'ค่าปรับค้างตัวอย่าง 65',N'https://example.test/evidence/65.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (26,66,2,'FUEL',N'ค่าปรับค้างตัวอย่าง 66',N'https://example.test/evidence/66.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (27,67,2,'EXCESS_MILEAGE',N'ค่าปรับค้างตัวอย่าง 67',N'https://example.test/evidence/67.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (28,68,2,'TRAFFIC',N'ค่าปรับค้างตัวอย่าง 68',N'https://example.test/evidence/68.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (29,69,2,'DAMAGE',N'ค่าปรับค้างตัวอย่าง 69',N'https://example.test/evidence/69.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (30,70,2,'LATE_RETURN',N'ค่าปรับค้างตัวอย่าง 70',N'https://example.test/evidence/70.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (31,71,2,'FUEL',N'ค่าปรับค้างตัวอย่าง 71',N'https://example.test/evidence/71.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (32,72,2,'EXCESS_MILEAGE',N'ค่าปรับค้างตัวอย่าง 72',N'https://example.test/evidence/72.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (33,73,2,'TRAFFIC',N'ค่าปรับค้างตัวอย่าง 73',N'https://example.test/evidence/73.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (34,74,2,'DAMAGE',N'ค่าปรับค้างตัวอย่าง 74',N'https://example.test/evidence/74.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (35,75,2,'LATE_RETURN',N'ค่าปรับค้างตัวอย่าง 75',N'https://example.test/evidence/75.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (36,76,2,'FUEL',N'ค่าปรับค้างตัวอย่าง 76',N'https://example.test/evidence/76.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (37,77,2,'EXCESS_MILEAGE',N'ค่าปรับค้างตัวอย่าง 77',N'https://example.test/evidence/77.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (38,78,2,'TRAFFIC',N'ค่าปรับค้างตัวอย่าง 78',N'https://example.test/evidence/78.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (39,79,2,'DAMAGE',N'ค่าปรับค้างตัวอย่าง 79',N'https://example.test/evidence/79.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
INSERT dbo.fine_damage ([fine_damage_id],[rental_id],[employee_id],[fine_type],[description],[evidence_url],[assessed_amount],[amount],[recorded_at],[due_at],[status],[waived_by_employee_id],[waived_at],[waiver_reason]) VALUES (40,80,2,'LATE_RETURN',N'ค่าปรับค้างตัวอย่าง 80',N'https://example.test/evidence/80.jpg',150,150,'2026-10-08T10:00:00','2026-10-14T10:00:00','UNPAID',NULL,NULL,NULL);
SET IDENTITY_INSERT dbo.fine_damage OFF;
COMMIT TRANSACTION;
END TRY
BEGIN CATCH
IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
SET IDENTITY_INSERT dbo.customer OFF;
SET IDENTITY_INSERT dbo.vehicle OFF;
SET IDENTITY_INSERT dbo.employee OFF;
SET IDENTITY_INSERT dbo.reservation OFF;
SET IDENTITY_INSERT dbo.rental OFF;
SET IDENTITY_INSERT dbo.payment OFF;
SET IDENTITY_INSERT dbo.fine_damage OFF;
THROW;
END CATCH;
GO
USE car_rental_mini_project;
SET NOCOUNT ON;
-- ขั้นที่ 1: จำนวนข้อมูล ตารางหลักมีการจองและสัญญาตัวอย่างอย่างละ 100
SELECT 'customer' AS table_name,COUNT(*) AS row_count FROM dbo.customer
UNION ALL SELECT 'vehicle',COUNT(*) FROM dbo.vehicle
UNION ALL SELECT 'employee',COUNT(*) FROM dbo.employee
UNION ALL SELECT 'reservation',COUNT(*) FROM dbo.reservation
UNION ALL SELECT 'rental',COUNT(*) FROM dbo.rental
UNION ALL SELECT 'payment',COUNT(*) FROM dbo.payment
UNION ALL SELECT 'fine_damage',COUNT(*) FROM dbo.fine_damage;
-- ขั้นที่ 2: สถานะรถและเลขไมล์
SELECT vehicle_id,registration_no,brand,model,vehicle_type,current_mileage,status,status_thai FROM dbo.vw_VehicleStatus ORDER BY vehicle_id;
-- ขั้นที่ 3: สัญญาและยอดเงินคงเหลือ
SELECT b.*,c.full_name,v.registration_no FROM dbo.vw_RentalBalance b JOIN dbo.customer c ON c.customer_id=b.customer_id JOIN dbo.vehicle v ON v.vehicle_id=b.vehicle_id ORDER BY b.rental_id;
-- ขั้นที่ 4: ประวัติการจอง
SELECT b.*,c.full_name,v.registration_no FROM dbo.reservation b JOIN dbo.customer c ON c.customer_id=b.customer_id JOIN dbo.vehicle v ON v.vehicle_id=b.vehicle_id ORDER BY b.reservation_id;
-- ขั้นที่ 5: ค่าปรับและความเสียหาย
SELECT f.*,r.rental_no,e.full_name AS recorded_by FROM dbo.fine_damage f JOIN dbo.rental r ON r.rental_id=f.rental_id JOIN dbo.employee e ON e.employee_id=f.employee_id;
-- ขั้นที่ 6: รายการเงินและทิศทาง ไม่รวมเงินประกันที่นำไปชำระซ้ำเป็นเงินสดรับ
SELECT p.*,CASE WHEN payment_method='DEPOSIT' THEN N'ใช้เงินประกันเดิม' WHEN payment_type='DEPOSIT_REFUND' THEN N'เงินออก' ELSE N'เงินเข้า' END AS direction FROM dbo.payment p ORDER BY payment_id;

-- รายการต่อไปนี้ควรได้ศูนย์แถว หากพบต้องตรวจข้อมูล
SELECT * FROM dbo.vw_RentalBalance WHERE deposit_balance<0 OR outstanding<0 OR (status='CLOSED' AND (outstanding<>0 OR deposit_balance<>0));
SELECT a.rental_id,b.rental_id AS conflict_rental FROM dbo.rental a JOIN dbo.rental b ON a.vehicle_id=b.vehicle_id AND a.rental_id<b.rental_id AND a.pickup_at<b.due_return_at AND b.pickup_at<a.due_return_at WHERE a.status<>'CANCELLED' AND b.status<>'CANCELLED';
SELECT r.rental_id FROM dbo.rental r JOIN dbo.reservation b ON b.reservation_id=r.reservation_id WHERE b.customer_id<>r.customer_id OR b.vehicle_id<>r.vehicle_id OR (r.status<>'CANCELLED' AND b.status<>'CONVERTED');
SELECT r.rental_id FROM dbo.rental r JOIN dbo.customer c ON c.customer_id=r.customer_id WHERE r.status<>'CANCELLED' AND (DATEADD(YEAR,20,c.birth_date)>CAST(r.pickup_at AS date) OR c.license_expiry_date<CAST(r.due_return_at AS date));

GO
