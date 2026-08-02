from furniture.models import NewFurnitureOptions, NewFurnitureImages
from cart.models import Cart
from notification.utils import create_order_status_notification
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.http import JsonResponse
from .models import UserAddresses, Orders, OrderItem
from .serializers import UserAddressSerializer, OrderListSerializer
from users.models import Users
from furniture.models import NewFurnitureOptions
from django.db import transaction
from notification.models import Notification

# 기본 배송지 조회
@api_view(['POST'])
def get_default_address(request):
    user_id = request.data.get('user_id')

    if not user_id:
        return Response({'message': 'user_id가 전달되지 않았습니다.'}, status=400)

    try:
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({'message': '해당 유저가 존재하지 않습니다.'}, status=404)

    try:
        default_address = UserAddresses.objects.get(user=user, is_default=True)
        serializer = UserAddressSerializer(default_address)
        return Response(serializer.data)
    except UserAddresses.DoesNotExist:
        return Response({'message': '기본 배송지가 설정되어 있지 않습니다.'}, status=404)

# 결제하기
@api_view(['POST'])
def process_payment(request):
    data = request.data
    user_id = data.get('user_id')
    used_point = int(data.get('usedPoint', 0))
    total_price = int(data.get('totalPrice', 0))

    try:
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({'success': False, 'message': '유저가 존재하지 않습니다.'}, status=400)

    if user.points < used_point:
        return Response({'success': False, 'message': '사용 가능한 포인트가 부족합니다.'}, status=400)

    # 포인트 차감
    user.points -= used_point

    # 적립 포인트 계산 (1%)
    final_payment = total_price - used_point
    earned_point = int(final_payment * 0.01)

    # 포인트 적립
    user.points += earned_point
    user.save()

    return Response({
        'success': True,
        'message': '포인트 차감 및 적립 완료',
        'earned_point': earned_point,
        'current_point': user.points
    })

# 주문 상세 저장
@api_view(['POST'])
def create_order(request):
    try:
        data = request.data
        user_id = data.get('user_id')
        total_price = data.get('total_price')
        items = data.get('items')

        user = Users.objects.get(user_id=user_id)

        with transaction.atomic():
            # 주문 생성
            order = Orders.objects.create(
                user=user,
                total_price=total_price,
                order_status='배송 준비'
            )

            # 주문 상세 + 판매량 증가
            for item in items:
                option = NewFurnitureOptions.objects.get(option_id=item['option_id'])

                # 주문 상세 저장
                OrderItem.objects.create(
                    order=order,
                    option=option,
                    quantity=item['quantity']
                )

                # 판매량 증가
                option.sold_count += item['quantity']
                option.save()

            # 대표 상품명 추출
            item_names = []
            for item in items:
                option = NewFurnitureOptions.objects.get(option_id=item['option_id'])
                item_names.append(option.product_id.name)

            # 메시지 만들기
            if len(item_names) == 1:
                message = f"{item_names[0]} 상품의 주문이 완료되었습니다."
            else:
                message = f"{item_names[0]} 외 {len(item_names) - 1}개 상품의 주문이 완료되었습니다."

            #주문 완료 알림 생성
            Notification.objects.create(
                user=user,
                title='주문 완료',
                message=message,
                type='order',  # 프론트에서 아이콘 정할 때 쓸 타입
                url=f'/order/detail/{order.pk}/',  # 누르면 주문 상세로
                is_read=False,
            )

        Cart.objects.filter(user_id=user, option_id__in=[item['option_id'] for item in items]).delete()

        return Response({'success': True, 'message': '주문이 완료되었습니다.'})

    except Exception as e:
        print('주문 실패:', e)
        return Response({'success': False, 'message': '주문 처리 중 오류 발생'}, status=500)

# 주문 내역 불러오기
@api_view(['POST'])
def get_user_orders(request):
    user_id = request.data.get('user_id')
    try:
        user = Users.objects.get(user_id=user_id)
        orders = Orders.objects.filter(user=user).order_by('-order_date')
        serializer = OrderListSerializer(orders, many=True)
        return Response(serializer.data)
    except Users.DoesNotExist:
        return Response({'message': '유저를 찾을 수 없습니다'}, status=404)

# 주문 내역 개수 불러오기
@api_view(['POST'])
def get_user_order_count(request):
    user_id = request.data.get('user_id')
    try:
        user = Users.objects.get(user_id=user_id)
        order_count = Orders.objects.filter(user=user).count()
        return Response({'count': order_count})
    except Users.DoesNotExist:
        return Response({'message': '유저를 찾을 수 없습니다'}, status=404)

# 배송지 목록 조회
@api_view(['POST'])
def get_user_addresses(request):
    user_id = request.data.get('user_id')

    try:
        user = Users.objects.get(user_id=user_id)
        addresses = UserAddresses.objects.filter(user=user).order_by('-is_default')
        serializer = UserAddressSerializer(addresses, many=True)
        return Response(serializer.data)
    except Users.DoesNotExist:
        return Response({'message': '유저를 찾을 수 없습니다'}, status=404)

# 배송지 추가
@api_view(['POST'])
def add_user_address(request):
    serializer = UserAddressSerializer(data=request.data)
    if serializer.is_valid():
        serializer.save()
        return Response({'message': '주소가 성공적으로 저장되었습니다.'}, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

# 기본 배송지 설정
@api_view(['POST'])
def set_default_address(request):
    user_id = request.data.get('user_id')
    address_id = request.data.get('address_id')

    if not user_id or not address_id:
        return Response({'error': 'user_id 또는 address_id가 누락되었습니다.'}, status=400)

    # 기존 기본 배송지를 false로 변경
    UserAddresses.objects.filter(user_id=user_id, is_default=True).update(is_default=False)

    # 선택한 주소를 기본 배송지로 변경
    updated = UserAddresses.objects.filter(user_id=user_id, address_id=address_id).update(is_default=True)

    if updated == 0:
        return Response({'error': '해당 주소가 존재하지 않음'}, status=404)

    return Response({'message': '기본 배송지가 변경되었습니다.'}, status=200)

# 배송지 수정
@api_view(['POST'])
def update_address(request):
    address_id = request.data.get('address_id')
    receiver_name = request.data.get('receiver_name')
    address = request.data.get('address')
    detail_address = request.data.get('detail_address')
    phone_number = request.data.get('phone_number')

    if not address_id:
        return Response({'error': 'address_id가 필요합니다.'}, status=400)

    try:
        addr = UserAddresses.objects.get(address_id=address_id)
        addr.receiver_name = receiver_name
        addr.address = address
        addr.detail_address = detail_address
        addr.phone_number = phone_number
        addr.save()
        return Response({'message': '주소가 성공적으로 수정되었습니다.'}, status=200)
    except UserAddresses.DoesNotExist:
        return Response({'error': '해당 주소를 찾을 수 없습니다.'}, status=404)

# 배송지 삭제
@api_view(['POST'])
def delete_address(request):
    address_id = request.data.get('address_id')

    if not address_id:
        return JsonResponse(
            {'error': 'address_id가 필요합니다.'},
            status=400,
            json_dumps_params={'ensure_ascii': False},
            content_type='application/json; charset=utf-8'
        )

    try:
        address = UserAddresses.objects.get(address_id=address_id)
        if address.is_default:
            return JsonResponse(
                {'error': '기본 배송지는 삭제할 수 없습니다.'},
                status=400,
                json_dumps_params={'ensure_ascii': False},
                content_type='application/json; charset=utf-8'
            )

        address.delete()
        return JsonResponse(
            {'message': '배송지가 삭제되었습니다.'},
            status=200,
            json_dumps_params={'ensure_ascii': False},
            content_type='application/json; charset=utf-8'
        )
    except UserAddresses.DoesNotExist:
        return JsonResponse(
            {'error': '주소를 찾을 수 없습니다.'},
            status=404,
            json_dumps_params={'ensure_ascii': False},
            content_type='application/json; charset=utf-8'
        )




# 인영언니
#장바구니 주문하기
@api_view(['POST'])
def place_order(request):
    user_id = request.data.get('user_id')
    option_ids = request.data.get('option_ids', [])
    #address_id = request.data.get('address_id')
    try:
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({'error': '유저를 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    cart_items = Cart.objects.filter(user_id=user, option_id__in=option_ids)
    if not cart_items.exists():
        return Response({'error': '주문할 항목이 없습니다.'}, status=status.HTTP_400_BAD_REQUEST)

    total_price = sum(item.option_id.price * item.quantity for item in cart_items)

    order = Orders.objects.create(user=user, total_price=total_price)

    for item in cart_items:
        OrderItem.objects.create(
            order=order,
            option_id=item.option_id,
            quantity=item.quantity,
            #address=address
        )

    cart_items.delete()  # 주문 후 장바구니 비우기

    return Response({'message': '주문이 완료되었습니다.', 'order_id': order.order_id}, status=status.HTTP_200_OK)

#주문 내역 보기
@api_view(['GET'])
def get_orders(request):
    user_id = request.GET.get('user_id')
    try:
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({'error': '유저를 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    orders = Orders.objects.filter(user=user).order_by('-order_date')
    result = []

    for order in orders:
        order_items = OrderItem.objects.filter(order=order)
        items_data = []

        for item in order_items:
            option = item.option
            product = option.product_id
            main_image = NewFurnitureImages.objects.filter(
                product_id=product.product_id,
                type='main'
            ).first()

            items_data.append({
                'product_name': product.name,
                'brand': product.brand,
                'option': f"{option.color} / {option.size}",
                'quantity': item.quantity,
                'price': item.price,
                'image_url': main_image.image_url if main_image else None
            })

        result.append({
            'order_id': order.order_id,
            'order_date': order.order_date.strftime('%Y.%m.%d'),
            'total_price': order.total_price,
            'status': order.status,
            'items': items_data
        })

    return Response({'orders': result}, status=status.HTTP_200_OK)


#주문 상태 변경 API
@api_view(['POST'])
def update_order_status(request, order_id):
    new_status = request.data.get("status")

    try:
        order = Orders.objects.get(id=order_id)
        order.status = new_status
        order.save()

        #알림 생성
        create_order_status_notification(order.user, order_id, new_status)

        return Response({"message": "주문 상태가 변경되었습니다."})
    except Orders.DoesNotExist:
        return Response({"error": "주문을 찾을 수 없습니다."}, status=404)