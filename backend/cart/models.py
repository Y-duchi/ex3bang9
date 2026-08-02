from django.db import models
from users.models import Users
from furniture.models import NewFurnitureOptions, NewFurnitureImages

class Cart(models.Model):
    cart_id = models.AutoField(primary_key=True)                                        #장바구니 ID
    user = models.ForeignKey(Users, on_delete=models.CASCADE, db_column='user_id')      #유저 ID
    option_id = models.ForeignKey(NewFurnitureOptions, on_delete=models.CASCADE, db_column='option_id')  #가구 옵션
    quantity = models.PositiveIntegerField(default=1)                                   #수량

    class Meta:
        db_table = 'cart'
        managed = False
