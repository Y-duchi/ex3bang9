from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .serializers import UserRegisterSerializer
from .models import Users, IdVerification
from report.models import Report, CommunityReport, CommentReport
from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
import hashlib
import hmac
from django.http import JsonResponse
import random
from django.core.mail import send_mail
from rest_framework.decorators import parser_classes
from rest_framework.parsers import MultiPartParser, FormParser


def verify_stored_password(raw_password: str, stored_hash: str) -> tuple[bool, bool]:
    """Return (matches, needs_upgrade) for Django and legacy SHA-256 hashes."""

    if check_password(raw_password, stored_hash):
        return True, False
    if len(stored_hash) == 64:
        legacy_hash = hashlib.sha256(raw_password.encode()).hexdigest()
        if hmac.compare_digest(legacy_hash, stored_hash):
            return True, True
    return False, False


# 회원가입
@api_view(['POST'])
def register(request):
    serializer = UserRegisterSerializer(data=request.data)
    if serializer.is_valid():
        data = serializer.validated_data

        # 아이디 중복 확인
        if Users.objects.filter(user_id=data['user_id']).exists():
            return Response(
                {'success': False, 'message': '이미 존재하는 아이디입니다.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        Users.objects.create(
            user_id=data['user_id'],
            password_hash=make_password(data['password_hash']),
            username=data['username'],
            nickname=data.get('nickname'),
            phone=data['phone'],
            email=data['email'],
            points=0,
            certification=False,
        )

        return Response(
            {'success': True, 'message': '회원가입 성공!'},
            status=status.HTTP_201_CREATED
        )

    return Response(
        {'success': False, 'message': serializer.errors},
        status=status.HTTP_400_BAD_REQUEST
    )

# 아이디 중복 확인
@api_view(['POST'])
def check_duplicate_user_id(request):
    user_id = request.data.get('user_id')
    if not user_id:
        return JsonResponse(
            {'success': False, 'message': '아이디를 입력하세요.'},
            json_dumps_params={'ensure_ascii': False}
        )
    if Users.objects.filter(user_id=user_id).exists():
        return JsonResponse(
            {'success': False, 'message': '이미 사용 중인 아이디입니다.'},
            json_dumps_params={'ensure_ascii': False}
        )
    else:
        return JsonResponse(
            {'success': True, 'message': '사용 가능한 아이디입니다.'},
            json_dumps_params={'ensure_ascii': False}
        )

# 이메일 인증번호 전송
email_verification_codes = {}
@api_view(['POST'])
def send_email_verification(request):
    email = request.data.get('email')
    if not email:
        return Response(
            {'success': False, 'message': '이메일을 입력하세요.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    code = str(random.randint(100000, 999999))
    email_verification_codes[email] = code

    send_mail(
        '이메일 인증번호',
        f'인증번호는 {code} 입니다.',
        settings.DEFAULT_FROM_EMAIL,
        [email],
        fail_silently=False,
    )

    return Response({'success': True, 'message': '인증번호가 이메일로 전송되었습니다.'})

# 이메일 인증번호 확인
@api_view(['POST'])
def verify_email_code(request):
    email = request.data.get('email')
    code  = request.data.get('code')

    if not email or not code:
        return Response(
            {'success': False, 'message': '이메일과 인증번호를 입력하세요.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    if email_verification_codes.get(email) == code:
        return Response({'success': True, 'message': '인증되었습니다.'})
    else:
        return Response(
            {'success': False, 'message': '인증번호가 일치하지 않습니다.'},
            status=status.HTTP_400_BAD_REQUEST
        )

# 로그인
@api_view(['POST'])
def login(request):
    user_id = request.data.get('user_id')
    password = request.data.get('password')
    if not user_id or not password:
        return Response(
            {'success': False, 'message': '아이디와 비밀번호를 입력하세요.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = Users.objects.filter(user_id=user_id).first()
    password_matches = False
    used_legacy_hash = False
    if user:
        password_matches, used_legacy_hash = verify_stored_password(
            password,
            user.password_hash,
        )

    if user and password_matches:
        if used_legacy_hash:
            user.password_hash = make_password(password)
            user.save(update_fields=['password_hash'])

        _id, nickname, points = user.user_id, user.nickname, user.points

        try:
            email = user.email

            report_blacklisted = Report.objects.filter(email=email, blacklisted=True).exists()
            community_blacklisted = CommunityReport.objects.filter(email=email, blacklisted=True).exists()
            comment_blacklisted = CommentReport.objects.filter(email=email, blacklisted=True).exists()

            if report_blacklisted or community_blacklisted or comment_blacklisted:
                return Response(
                    {'success': False, 'message': '이 계정은 블랙리스트 처리되어 사용이 제한됩니다.'},
                    status=status.HTTP_403_FORBIDDEN
                )

        except Users.DoesNotExist:
            email = None

        return Response({
            'success': True,
            'message': '로그인 성공 !',
            'user_id': _id,
            'nickname': nickname,
            'points': points,
            'email': email,
            'certification': user.certification,
        })
    else:
        return Response(
            {'success': False, 'message': '아이디 또는 비밀번호가 틀렸습니다.'},
            status=status.HTTP_400_BAD_REQUEST
        )


# 카카오 로그인
@api_view(['POST'])
def kakao_login(request):
    kakao_id = request.data.get('kakao_id')
    nickname = request.data.get('nickname')
    email    = request.data.get('email')

    if not kakao_id:
        return Response(
            {'success': False, 'message': '카카오 ID가 없습니다.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    user, created = Users.objects.get_or_create(
        user_id=kakao_id,
        defaults={
            'username': nickname or '',
            'nickname': nickname or '',
            'email':    email or '',
            'password_hash': '',
            'phone': '',
            'points': 0,
            'certification': False,
            'login_type': 'kakao',
        }
    )

    return Response({
        'success': True,
        'message': '카카오 로그인 완료',
        'user_id': user.user_id,
        'nickname': user.nickname,
        'points': user.points,
    })

# 네이버 로그인
@api_view(['POST'])
def naver_login(request):
    naver_id = request.data.get('naver_id')
    username = request.data.get('username')
    nickname = request.data.get('nickname')
    email    = request.data.get('email')
    phone    = request.data.get('phone')

    if not naver_id:
        return Response(
            {'success': False, 'message': '네이버 ID가 없습니다.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    user, created = Users.objects.get_or_create(
        user_id=naver_id,
        defaults={
            'username': username or '',
            'nickname': nickname or '',
            'email':    email or '',
            'password_hash': '',
            'phone': phone or '',
            'points': 0,
            'certification': False,
            'login_type': 'naver',
        }
    )

    return Response({
        'success': True,
        'message': '네이버 로그인 완료',
        'user_id': user.user_id,
        'nickname': user.nickname,
        'points': user.points,
    })

# 탈퇴
@api_view(['DELETE'])
def delete_user(request, user_id):
    try:
        user = Users.objects.get(user_id=user_id)
        user.delete()  # 연쇄 삭제 수행됨
        return Response({'message': '탈퇴 성공'}, status=200)
    except Users.DoesNotExist:
        return Response({'message': '사용자를 찾을 수 없습니다'}, status=404)



# 2차 인증
@api_view(['POST'])
def verify_id(request):
    try:
        user_id = request.data.get('user_id')
        name = request.data.get('name')
        issued_date = request.data.get('issued_date')
        id_front = request.data.get('id_number_front')
        id_back = request.data.get('id_number_back')


        if not (user_id and name and issued_date and id_front and id_back):
            return Response({'success': False, 'message': '모든 필드를 입력하세요.'}, status=400)

        if not Users.objects.filter(user_id=user_id).exists():
            return Response({'success': False, 'message': '존재하지 않는 사용자입니다.'}, status=404)

        IdVerification.objects.update_or_create(
            user_id=user_id,
            defaults={
                'name': name,
                'issued_date': issued_date,
                'id_number_front': id_front,
                'id_number_back': id_back,
            }
        )

        Users.objects.filter(user_id=user_id).update(certification=True)

        return Response({'success': True, 'message': '2차 인증 성공!'})
    except Exception as e:
        return Response({'success': False, 'message': str(e)}, status=500)

# 포인트 조회
@api_view(['POST'])
def get_user_point(request):
    user_id = request.data.get('user_id')

    try:
        user = Users.objects.get(user_id=user_id)
        return Response({'point': user.points}, status=status.HTTP_200_OK)
    except Users.DoesNotExist:
        return Response({'error': '해당 유저가 존재하지 않습니다.'}, status=status.HTTP_404_NOT_FOUND)

#채팅 유저 정보 가져오기
@api_view(['GET'])
def get_all_users(request):
    users = Users.objects.all().values('user_id', 'username', 'nickname')
    users = [{'user_id': u['user_id'], 'username': u['username'], 'nickname': u['nickname']} for u in users]
    return JsonResponse(users, safe=False)

# 회원 정보 조회
@api_view(['POST'])
def get_user_info(request):
    user_id = request.data.get('user_id')

    try:
        user = Users.objects.get(user_id=user_id)
        image_url = None
        if user.profile_image:
            image_url = request.build_absolute_uri(user.profile_image.url)

        data = {
            'name': user.username,
            'nickname': user.nickname,
            'phone': user.phone,
            'email': user.email,
            'profile_image': image_url,
        }
        return Response(data, status=200)
    except Users.DoesNotExist:
        return Response({'message': '유저를 찾을 수 없습니다'}, status=404)

# 회원 정보 수정
@api_view(['POST'])
def update_user_field(request):
    user_id = request.data.get('user_id')
    field = request.data.get('field')
    value = request.data.get('value')

    if not user_id or not field or value is None:
        return Response({'error': '필수 값이 누락되었습니다.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        user = Users.objects.get(user_id=user_id)
    except Users.DoesNotExist:
        return Response({'error': '유저를 찾을 수 없습니다.'}, status=status.HTTP_404_NOT_FOUND)

    # 허용된 필드만 수정
    allowed_fields = ['username', 'nickname', 'phone', 'email']
    if field not in allowed_fields:
        return Response({'error': '수정할 수 없는 필드입니다.'}, status=status.HTTP_400_BAD_REQUEST)

    setattr(user, field, value)
    user.save()

    return Response({'message': f'{field}가 성공적으로 수정되었습니다.'}, status=status.HTTP_200_OK)

# 프로필 이미지 저장
@api_view(['POST'])
@parser_classes([MultiPartParser, FormParser])
def upload_profile_image(request):
    user_id = request.data.get('user_id')
    image = request.FILES.get('image')

    if not user_id or not image:
        return Response({'error': 'user_id 또는 image가 누락되었습니다.'}, status=400)

    try:
        user = Users.objects.get(user_id=user_id)
        user.profile_image = image
        user.save()
        return Response({'message': '이미지가 업로드되었습니다.'}, status=200)
    except Users.DoesNotExist:
        return Response({'error': '사용자를 찾을 수 없습니다.'}, status=404)
