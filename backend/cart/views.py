from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import Cart, NewFurnitureOptions, NewFurnitureImages
from users.models import Users

#장바구니 담기
@api_view(['POST'])
def add_to_cart(request):
    user_id = request.data.get('user_id')
    option_id = request.data.get('option_id')
    quantity = int(request.data.get('quantity', 1))

    #사용자 및 옵션 확인
    try:
        user = Users.objects.get(user_id=user_id)
        option = NewFurnitureOptions.objects.get(option_id=option_id)
    except Users.DoesNotExist:
        return Response({'error': '유저를 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)
    except NewFurnitureOptions.DoesNotExist:
        return Response({'error': '옵션을 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    #장바구니에 이미 있는지 확인
    existing_item = Cart.objects.filter(user_id=user, option_id=option).first()
    if existing_item:
        existing_item.quantity += quantity
        existing_item.save()  #동일 옵션 있으면 수량 증가
    else:
        Cart.objects.create(user_id=user.user_id, option_id=option, quantity=quantity) #객체 수정

    return Response({'message': '장바구니에 담았습니다'}, status=status.HTTP_200_OK)

# 장바구니 담긴 상품 조회
@api_view(['GET'])
def get_cart_items(request):
    user_id = request.GET.get('user_id')

    try:
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({'error': '유저를 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    cart_items = Cart.objects.filter(user_id=user)

    result = []
    for item in cart_items:
        option = item.option_id
        product = option.product_id
        main_image = NewFurnitureImages.objects.filter(
            product_id=product.product_id,
            type='main'
        ).first()

        image_url = None
        if main_image and main_image.image_url:
            image_url = main_image.image_url.strip()

        result.append({
            'product_id': str(product.product_id),
            'cart_id': item.cart_id,
            'option_id': option.option_id,
            'product_name': product.name,
            'option': f"{option.color} / {option.size}",
            'quantity': item.quantity,
            'price': option.price,
            'image_url': image_url,
            'delivery_fee': item.option_id.product_id.delivery_fee,
            'discount': 0,
        })

    return Response({'cart': result}, content_type='application/json; charset=utf-8')



#장바구니 수량 수정
@api_view(['POST'])
def update_cart_quantity(request):
    user_id = request.data.get('user_id')
    option_id = request.data.get('option_id')
    new_quantity = int(request.data.get('quantity', 1))
    try:
        user = Users.objects.get(user_id=user_id)
        option = NewFurnitureOptions.objects.get(option_id=option_id)
    except (Users.DoesNotExist, NewFurnitureOptions.DoesNotExist):
        return Response({'error': '유저나 옵션을 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    cart_item = Cart.objects.filter(user_id=user, option_id=option).first()
    if not cart_item:
        return Response({'error': '해당 장바구니 항목이 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    if new_quantity <=0:
        cart_item.delete()
        return Response({'message': '장바구니에서 삭제(수량 0)했습니다.'}, status=status.HTTP_200_OK)

    cart_item.quantity = new_quantity
    cart_item.save()
    return Response({'message': '수량이 추가되었습니다.'}, status=status.HTTP_200_OK)


#장바구니 옵션 수정
@api_view(['POST'])
def update_cart_option(request):
    user_id = request.data.get('user_id')
    old_option_id = request.data.get('old_option_id')
    new_option_id = request.data.get('new_option_id')
    try:
        user = Users.objects.get(user_id=user_id)
        old_option = NewFurnitureOptions.objects.get(option_id=old_option_id)
        new_option = NewFurnitureOptions.objects.get(option_id=new_option_id)
    except (Users.DoesNotExist, NewFurnitureOptions.DoesNotExist):
        return Response({'error': '유저 또는 옵션 정보를 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    existing_item = Cart.objects.filter(user_id=user, option_id=old_option).first()
    if not existing_item:
        return Response({'error': '해당 장바구니 항목이 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    #기존 항목 삭제
    quantity = existing_item.quantity
    existing_item.delete()

    #새 옵션으로 추가 (중복이면 수량 증가)
    new_item = Cart.objects.filter(user_id=user, option_id=new_option).first()
    if new_item:
        new_item.quantity += quantity
        new_item.save()
    else:
        Cart.objects.create(user_id=user, option_id=new_option, quantity=quantity)

    return Response({'message': '옵션이 변경되었습니다'}, status=status.HTTP_200_OK)


#장바구니 삭제
@api_view(['POST'])
def delete_cart_items(request):
    user_id = request.data.get('user_id')
    option_ids = request.data.get('option_ids', []) #리스트 화
    try :
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({'error': '유저를 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    Cart.objects.filter(user_id=user, option_id__in=option_ids).delete()
    return Response({'message': '선택된 항목을 삭제했습니다.'}, status=status.HTTP_200_OK)