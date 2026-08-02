from django.db import models
from furniture.models import UsedFurniture
from  community.models import Post, Comment

# 중고거래 신고
class Report(models.Model):
    email = models.CharField(max_length=100, primary_key=True)
    report_count = models.IntegerField(default=0)
    blacklisted = models.BooleanField(default=False)

    class Meta:
        db_table = 'report'

# 중고거래 신고 로그
class ReportLog(models.Model):
    report_id = models.AutoField(primary_key=True)
    reported_email = models.CharField(max_length=100)
    reporter_email = models.CharField(max_length=100)
    post = models.ForeignKey(UsedFurniture, on_delete=models.CASCADE, db_column='post_id')
    reason = models.TextField()
    content = models.TextField()
    report_date = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'report_log'

# 커뮤니티 신고
class CommunityReport(models.Model):
    email        = models.CharField(max_length=100, primary_key=True)  # 신고 대상자 이메일
    report_count = models.IntegerField(default=0)
    blacklisted  = models.BooleanField(default=False)
    class Meta:
        db_table = 'community_report'

# 커뮤니티 신고 로그
class CommunityReportLog(models.Model):
    report_id      = models.AutoField(primary_key=True)
    reported_email = models.CharField(max_length=100)
    reporter_email = models.CharField(max_length=100)
    post           = models.ForeignKey(Post, on_delete=models.CASCADE, db_column='post_id')
    reason         = models.TextField()
    content        = models.TextField()
    report_date    = models.DateTimeField(auto_now_add=True)
    class Meta:
        db_table = 'community_report_log'

# 댓글 신고
class CommentReport(models.Model):
    email        = models.CharField(max_length=100, primary_key=True)
    report_count = models.IntegerField(default=0)
    blacklisted  = models.BooleanField(default=False)
    class Meta:
        db_table = 'comment_report'

# 댓글 신고 로그
class CommentReportLog(models.Model):
    report_id      = models.AutoField(primary_key=True)
    reported_email = models.CharField(max_length=100)
    reporter_email = models.CharField(max_length=100)
    comment        = models.ForeignKey(Comment, on_delete=models.CASCADE, db_column='comment_id')
    reason         = models.TextField()
    content        = models.TextField()
    report_date    = models.DateTimeField(auto_now_add=True)
    class Meta:
        db_table = 'comment_report_log'
