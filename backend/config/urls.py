from django.contrib import admin
from django.urls import path, include
from users.views import register, verify_id, get_all_users, delete_user, check_duplicate_user_id, login, send_email_verification, verify_email_code, kakao_login, naver_login, get_user_point, get_user_info, update_user_field, upload_profile_image
from furniture.views import furniture_list, trendy_furniture_list, get_used_furniture_chat_info, get_favorite_count, popular_furniture_list, furniture_detail, get_furniture_options, used_furniture_list, create_used_furniture, used_furniture_detail
from django.conf import settings
from django.conf.urls.static import static
from django.http import JsonResponse
from furniture.views import toggle_favorite, get_product_options, get_favorite_items, mark_sold, get_user_sale_counts, sold_furniture_list
from report.views import create_report_log, create_community_report, create_comment_report
from cart.views import add_to_cart, get_cart_items, update_cart_quantity, update_cart_option, delete_cart_items
from orders.views import  get_default_address, process_payment, create_order, get_user_orders, get_user_order_count, get_user_addresses, add_user_address, set_default_address, update_address, delete_address, place_order, get_orders, update_order_status
from inquiry.views import get_inquiries, get_inquiries_by_product, create_inquiry, get_inquiry_detail, update_inquiry, delete_inquiry, answer_inquiry
from notification.views import get_notification, get_unread_notification_count, mark_notification_read
from reviews.views import create_new_furniture_review, get_my_review_count, get_review_count, update_new_review, delete_new_review, get_average_rating, get_reviews_by_user, get_reviews_by_option, get_reviews_by_product, has_user_reviewed_option


def health(_request):
    return JsonResponse({'status': 'ok', 'service': 'bang9-django'})


urlpatterns = [
    path('health/', health),
    path('admin/', admin.site.urls),

    # 사용자 API
    path('register/', register),
    path('check_user_id/', check_duplicate_user_id),
    path('login/', login),
    path('send_email_verification/', send_email_verification),
    path('verify_email_code/', verify_email_code),
    path('kakao_login/', kakao_login),
    path('naver_login/', naver_login),
    path('get_user_point/', get_user_point),
    path('delete_user/<str:user_id>/', delete_user),
    path('verify_id/', verify_id),
    path('get_user_info/', get_user_info),
    path('update_user_field/', update_user_field),
    path('upload_profile_image/', upload_profile_image),
    path('community/', include('community.urls')),
    path('get_user_sale_counts/', get_user_sale_counts, name='get_user_sale_counts'),


    # 새 가구 API
    path('furniture_list/', furniture_list),
    path('furniture_detail/<int:product_id>/', furniture_detail),
    path('get_furniture_options/<int:product_id>/', get_furniture_options),

    # 중고거래 API
    path('used_furniture_list/', used_furniture_list),
    path('create_used_furniture/', create_used_furniture),
    path('used_furniture/<int:post_id>/', used_furniture_detail),
    path('used_furniture/mark_sold/<int:post_id>/', mark_sold, name='mark_sold'),
    path('sold_furniture_list/', sold_furniture_list),


    # 신고 API
    path('report/', create_report_log),
    path('report/community_post/', create_community_report),
    path('report/comment/', create_comment_report),

    #채팅 유저정보 API
    path('get_all_users/', get_all_users),

    # 이달의 가구 API
    path('favorite_items/<str:user_id>/', get_favorite_items, name='get_favorite_items'),
    path('favorite_items/', toggle_favorite),
    path('popular_furniture_list/', popular_furniture_list),
    path('favorite/count/', get_favorite_count),
    path('trendy_furniture_list/', trendy_furniture_list),

    # 배송 API
    path('get_default_address/', get_default_address),

    #장바구니 API
    path('add_to_cart/', add_to_cart),
    path('get_cart_items/', get_cart_items),
    path('update_cart_quantity/', update_cart_quantity),
    path('update_cart_option/', update_cart_option),
    path('delete_cart_items/', delete_cart_items),
    path('get_used_furniture_chat_info/', get_used_furniture_chat_info),
    path('get_product_options/', get_product_options),

    #주문 API
    path('place_order/',place_order),
    path('get_orders/', get_orders),
    path('update_order_status/', update_order_status),
    path('get_default_address/', get_default_address),
    path('process_payment/', process_payment),
    path('create_order/', create_order),
    path('get_user_orders/', get_user_orders),
    path('get_user_order_count/', get_user_order_count),
    path('get_user_addresses/', get_user_addresses),
    path('add_user_address/', add_user_address),
    path('set_default_address/', set_default_address),
    path('update_address/', update_address),
    path('delete_address/', delete_address),

    #리뷰 API
    path('create_new_furniture_review/', create_new_furniture_review),
    path('get_reviews_by_user/', get_reviews_by_user),
    path('get_reviews_by_option/', get_reviews_by_option),
    path('get_reviews_by_product/', get_reviews_by_product),
    path('update_new_review/<int:review_id>/', update_new_review),
    path('delete_new_review/<int:review_id>/', delete_new_review),
    path('get_average_rating/', get_average_rating),
    path('get_review_count/', get_review_count),
    path('get_my_review_count/', get_my_review_count),
    path('has_user_reviewed_option/', has_user_reviewed_option),


    #문의 API

    path('create_inquiry/', create_inquiry),
    path('get_inquiries/', get_inquiries),
    path('get_inquiry_detail/', get_inquiry_detail),
    path('update_inquiry/<int:inquiry_id>/', update_inquiry),
    path('delete_inquiry/<int:inquiry_id>/', delete_inquiry),
    path('answer_inquiry/<int:inquiry_id>/', answer_inquiry),
    path('get_inquiries_by_product/', get_inquiries_by_product),



    #알림 API
    path('get_notification/', get_notification),
    path('get_unread_notification_count/', get_unread_notification_count),
    path('mark_notifications_read/', mark_notification_read),

    # 검색 API
    path('search/', include('search.urls')),

]

# media 파일 경로 추가
urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
