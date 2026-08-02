from django.db import models


class Users(models.Model):
    user_id = models.CharField(max_length=50, primary_key=True)         # 유저 ID
    password_hash = models.CharField(max_length=255)                    # 비밀번호 해시값
    username = models.CharField(max_length=50)                          # 이름
    nickname = models.CharField(max_length=50, null=True, blank=True)   # 닉네임
    phone = models.CharField(max_length=20)                             # 전화번호
    email = models.CharField(max_length=100)                            # 이메일
    points = models.IntegerField(default=0)                             # 포인트
    certification = models.BooleanField(default=False)                  # 2차 인증 여부
    login_type = models.CharField(max_length=20, default='normal')      # 로그인 종류
    profile_image = models.ImageField(upload_to='profile_images/', null=True, blank=True) # 프로필 이미지

    class Meta:
        db_table = 'users' # 실제 MySQL 테이블명
        managed = False # Django가 테이블을 직접 관리하지 않음



# models.py 하단에 추가
class IdVerification(models.Model):
    user = models.OneToOneField('Users', on_delete=models.CASCADE, db_column='user_id', primary_key=True)
    name = models.CharField(max_length=50)
    issued_date = models.DateField(null=True, blank=True)
    id_number_front = models.CharField(max_length=6)  # 주민번호 앞자리 (예: 990101)
    id_number_back = models.CharField(max_length=1)   # 주민번호 뒷자리 일부 (예: 2)

    class Meta:
        db_table = 'ID'