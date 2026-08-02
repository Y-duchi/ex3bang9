from .models import Notification
from furniture.models import UsedFurniture
from community.models import Post


#주문 상태 변경 시 알림 함수
def create_order_status_notification(user, order_id, new_status):
    if new_status == "배송중":
        title = "배송 시작"
        message = f"주문하신 상품이 배송을 시작했습니다."
    elif new_status == "배송완료":
        title = "배송 완료"
        message = f"주문하신 상품이 배송 완료되었습니다."
    elif new_status == "취소":
        title = "주문 취소"
        message = f"주문이 취소되었습니다."
    elif new_status == "결제완료":
        title = "결제 완료"
        message = f"주문 결제가 완료되었습니다."
    else:
        title = "주문 상태 변경"
        message = f"주문 상태가 '{new_status}'로 변경되었습니다."

    Notification.objects.create(
        user=user,
        title=title,
        message=message,
        type="order_status",
        url=f"/orders/{order_id}/"
    )

#문의 답변 시 알림 함수
def create_inquiry_answer_notification(user, inquiry_id, product_title):
    title = "문의"
    message = f"'{product_title}' 상품에 남기신 문의에 대한 답변이 등록되었습니다."

    Notification.objects.create(
        user=user,
        title=title,
        message=message,
        type="inquiry",
        url=f"/inquiry/{inquiry_id}/"
    )

#댓글 알림
def create_comment_notification(writer, target_user, content_type, content_id):
    title_text = ""
    url = "/"

    if content_type == 'community/post':
        try:
            post = Post.objects.get(id=content_id)
            title_text = post.title
            url = f"/community/posts/{content_id}/"
        except Post.DoesNotExist:
            title_text = "(삭제된 게시글)"
            url = "/community/posts/"

    message = f"{writer.nickname}님이 회원님의 '{title_text}' 게시글에 댓글을 작성했습니다."

    Notification.objects.create(
        user=target_user,                 # 알림 받는 유저
        title="내 게시물",                 # 알림 제목
        message=message,                 # 본문 메시지
        type="comment",                  # 알림 타입
        url=url                          # 이동할 페이지 URL
    )

#좋아요 알림
def create_like_notification(from_user, to_user, content_type, content_id):
    if content_type == 'used':
        try:
            content = UsedFurniture.objects.get(post_id=content_id)
            title = content.title
            url = f"/used/posts/{content_id}/"
        except UsedFurniture.DoesNotExist:
            title = '(삭제된 게시글)'
            url = "/used/posts/"
        notif_title = "중고 상품"

    elif content_type == 'community':
        try:
            post = Post.objects.get(id=content_id)
            title = post.title
            url = f"/community/posts/{content_id}/"
        except Post.DoesNotExist:
            title = '(삭제된 게시글)'
            url = "/community/posts/"
        notif_title = "내 게시글"

    message = f"{from_user.nickname}님이 회원님의 '{title}' 게시글에 좋아요를 눌렀습니다."

    Notification.objects.create(
        user=to_user,
        title=notif_title,
        message=message,
        type="like",
        url=url
    )