const admin = require('firebase-admin');
const geohash = require('ngeohash');

// 1. 서비스 계정 키 파일 경로 (유저가 바탕화면에 저장한 파일)
const serviceAccount = require('C:\\Users\\spott\\OneDrive\\Desktop\\Game\\firebase_admin_key.json.json');

// 2. Firebase Admin 초기화
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 3. 서울 지역 위경도 바운더리
// 위도: 37.45 ~ 37.65
// 경도: 126.85 ~ 127.15
function getRandomArbitrary(min, max) {
  return Math.random() * (max - min) + min;
}

const names = ['거대 화염 드래곤', '바위 골렘 보스', '바람의 정령왕', '푸른 바다뱀', '황금 기사단장'];

async function generateRaids(count) {
  console.log(`🚀 서울 지역에 ${count}마리의 보스를 배치합니다...`);
  const batch = db.batch();
  
  for (let i = 0; i < count; i++) {
    const lat = getRandomArbitrary(37.45, 37.65);
    const lng = getRandomArbitrary(126.85, 127.15);
    
    // geoflutterfire_plus 규격에 맞는 데이터 생성
    const hash = geohash.encode(lat, lng);
    
    const docRef = db.collection('world_raids').doc(`seoul_boss_${i}`);
    
    batch.set(docRef, {
      bossName: names[Math.floor(Math.random() * names.length)],
      level: Math.floor(Math.random() * 50) + 10, // 10 ~ 59
      status: 'active',
      // 구버전 호환용
      location: new admin.firestore.GeoPoint(lat, lng),
      // 최적화된 Geofencing을 위한 핵심 필드 (geoflutterfire_plus 규격)
      geo: {
        geopoint: new admin.firestore.GeoPoint(lat, lng),
        geohash: hash
      }
    });
  }
  
  await batch.commit();
  console.log('✅ 100마리 보스 배치 완료!');
}

generateRaids(100).catch(console.error);
