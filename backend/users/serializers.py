from rest_framework import serializers
from .models import Users

class UserRegisterSerializer(serializers.ModelSerializer):
    password_confirm = serializers.CharField(write_only=True)  # 비밀번호 확인용

    class Meta:
        model = Users
        fields = ['user_id', 'password_hash', 'password_confirm', 'username', 'nickname', 'phone', 'email']

    def validate(self, data):
        if data['password_hash'] != data['password_confirm']:
            raise serializers.ValidationError("비밀번호가 일치하지 않습니다.")
        return data