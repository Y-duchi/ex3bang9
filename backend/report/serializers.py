from rest_framework import serializers
from .models import ReportLog, CommunityReportLog, CommentReportLog

class ReportLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = ReportLog
        fields = '__all__'

class CommunityReportLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = CommunityReportLog
        fields = '__all__'


class CommentReportLogSerializer(serializers.ModelSerializer):
    class Meta:
        model = CommentReportLog
        fields = '__all__'