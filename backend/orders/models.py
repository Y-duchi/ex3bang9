from django.db import models
from users.models import Users
from furniture.models import NewFurnitureOptions

# 주소 테이블
class UserAddresses(models.Model):
    address_id = models.AutoField(primary_key=True)             # 주소 ID
    user = models.ForeignKey(Users, on_delete=models.CASCADE)   # 유저 ID
    receiver_name = models.CharField(max_length=50)             # 받는 사람
    address = models.CharField(max_length=100)                  # 주소
    detail_address = models.CharField(max_length=50)            # 상세주소
    phone_number = models.CharField(max_length=20)              # 연락처
    is_default = models.BooleanField(default=False)             # 기본 배송지 여부

    class Meta:
        db_table = 'user_addresses'
        managed = False

# 주문 테이블
class Orders(models.Model):
    order_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(Users, on_delete=models.CASCADE)
    total_price = models.IntegerField()
    order_status = models.CharField(max_length=20, default='배송 준비')
    order_date = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'orders'
        managed = False

# 주문 상세 테이블
class OrderItem(models.Model):
    orderitem_id = models.AutoField(primary_key=True)
    order = models.ForeignKey(Orders, on_delete=models.CASCADE)
    option = models.ForeignKey(NewFurnitureOptions, on_delete=models.CASCADE)
    quantity = models.IntegerField()

    class Meta:
        db_table = 'orderitem'
        managed = False