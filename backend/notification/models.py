from django.db import models
from users.models import Users

class Notification(models.Model):
    notifi_id = models.AutoField(primary_key=True)              #알림 ID
    user = models.ForeignKey(Users, on_delete=models.CASCADE)   #수신자
    title = models.CharField(max_length=50)                     #알림 제목(배송, 문의 등)
    message = models.TextField()                                #알림 메시지 내용
    type = models.CharField(max_length=30)                      #프론트 아이콘 매핑용 (필요 없으면 지우기)
    url = models.CharField(max_length=255)                      #클릭 시 이동할 주소
    is_read = models.BooleanField(default=False)                #읽음 여부
    created_at = models.DateTimeField(auto_now_add=True)        #알림 시각

    class Meta:
        db_table = 'notification'
        managed = False
