//
//  ContentView.swift
//  Plantdoc-app
//
//  Created by doi on 2025/07/16.
//

import SwiftUI
import ARKit
import CoreML
import Vision
import RealityKit
import AVFoundation

struct ContentView: View {
    @StateObject private var arViewModel = ARViewModel()
    @State private var showCameraPermissionAlert = false
    @State private var isViewReady = false
    
    init() {
        print("ContentView: 初期化されました")
    }
    
    var body: some View {
        let _ = print("ContentView: bodyが呼ばれました")
        let _ = print("ContentView: arViewModel = \(arViewModel)")
        let _ = print("ContentView: arViewModel.isSetupComplete = \(arViewModel.isSetupComplete)")
        ZStack {
            // AR View
            let _ = print("ARViewContainerを表示します")
            let _ = print("arViewModel: \(arViewModel)")
            let _ = print("arViewModel.arView: \(arViewModel.arView)")
            
            // ARViewContainerを確実に表示
            ARViewContainer(arViewModel: arViewModel)
                .edgesIgnoringSafeArea(.all)
                .id(UUID()) // 強制的に再描画
                .background(Color.clear) // 背景を透明に
                .onAppear {
                    print("ContentView: ARViewContainer appeared")
                    print("ARViewContainer: arViewModel = \(arViewModel)")
                    // setupARを確実に呼び出す
                    DispatchQueue.main.async {
                        print("ContentView: Calling setupAR from onAppear")
                        arViewModel.setupAR()
                    }
                    // 少し遅延してから準備完了
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isViewReady = true
                    }
                }
                .onDisappear {
                    print("ContentView: ARViewContainer disappeared")
                    // ARViewのセッションを停止
                    arViewModel.cleanup()
                }
            
            // UI Overlay
            if isViewReady {
                VStack {
                    Spacer()
                    
                    // 診断結果表示
                    if let result = arViewModel.classificationResult {
                        VStack {
                            Text("診断結果")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(result.className)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("信頼度: \(String(format: "%.1f", result.confidence * 100))%")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding()
                    } else {
                        // 診断結果がない場合の表示
                        VStack {
                            Text("診断結果なし")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text("植物をカメラに向けてください")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding()
                    }
                    
                    // コントロールボタン
                    HStack {
                        Button(action: {
                            print("診断開始/停止ボタンが押されました")
                            checkCameraPermission {
                                print("カメラ権限確認完了、診断状態を切り替え")
                                arViewModel.isClassificationEnabled.toggle()
                                print("診断状態: \(arViewModel.isClassificationEnabled)")
                            }
                        }) {
                            Text(arViewModel.isClassificationEnabled ? "診断停止" : "診断開始")
                                .foregroundColor(.white)
                                .padding()
                                .background(arViewModel.isClassificationEnabled ? Color.red : Color.green)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            print("リセットボタンが押されました")
                            arViewModel.resetSession()
                        }) {
                            Text("リセット")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            print("ContentView: View appeared")
            setupCameraPermission()
        }
        .alert("カメラ権限が必要です", isPresented: $showCameraPermissionAlert) {
            Button("設定を開く") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("植物診断機能を使用するにはカメラへのアクセス権限が必要です。設定アプリで権限を許可してください。")
        }
    }
    
    private func checkCameraPermission(completion: @escaping () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        completion()
                    } else {
                        showCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionAlert = true
        @unknown default:
            showCameraPermissionAlert = true
        }
    }
    
    private func setupCameraPermission() {
        // アプリ起動時にカメラ権限を確認
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.showCameraPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionAlert = true
        default:
            break
        }
    }
}

// AR View Container
struct ARViewContainer: UIViewRepresentable {
    let arViewModel: ARViewModel
    
    init(arViewModel: ARViewModel) {
        print("ARViewContainer: 初期化されました")
        print("ARViewContainer: arViewModel = \(arViewModel)")
        self.arViewModel = arViewModel
    }
    
    func makeCoordinator() -> Coordinator {
        print("ARViewContainer: makeCoordinator called")
        return Coordinator(self)
    }
    
    func makeUIView(context: Context) -> ARView {
        print("=== ARViewContainer: makeUIView called ===")
        print("ARViewContainer: context = \(context)")
        
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: true)
        arView.backgroundColor = .clear // 背景を透明にしてカメラ映像を表示
        
        print("ARViewを作成しました: \(arView)")
        
        // 即座にARViewModelを設定
        print("ARViewContainer: Setting up AR immediately")
        print("arViewModel: \(arViewModel)")
        arViewModel.arView = arView
        print("arViewを設定しました")
        
        // 即座にsetupARを呼び出し（メインスレッドで）
        print("ARViewContainer: Calling setupAR immediately")
        arViewModel.setupAR()
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        print("ARViewContainer: updateUIView called")
        print("ARViewContainer: uiView = \(uiView)")
        
        // updateUIViewでは重複実行を避ける
        if arViewModel.arView == nil {
            print("ARViewContainer: Setting arView in updateUIView")
            arViewModel.arView = uiView
            // setupARはmakeUIViewで既に呼ばれるので、ここでは呼ばない
        }
    }
    
    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        print("ARViewContainer: dismantleUIView called")
        // ARViewのセッションを停止
        uiView.session.pause()
    }
    
    // Coordinator class for UIViewRepresentable
    class Coordinator: NSObject {
        let parent: ARViewContainer
        
        init(_ parent: ARViewContainer) {
            self.parent = parent
            print("ARViewContainer: Coordinator initialized")
        }
    }
}

// AR View Model
class ARViewModel: NSObject, ObservableObject {
    @Published var classificationResult: ClassificationResult?
    @Published var isClassificationEnabled = false
    
    var arView: ARView?
    private var classificationRequest: VNCoreMLRequest?
    private var mlModel: MLModel?
    private var lastClassificationTime: Date = Date()
    var isSetupComplete = false
    
    struct ClassificationResult {
        let className: String
        let confidence: Float
    }
    
    override init() {
        super.init()
        print("ARViewModel: 初期化されました")
        print("ARViewModel: self = \(self)")
    }
    
    deinit {
        // リソースのクリーンアップ
        cleanup()
        print("ARViewModel: deinit called")
    }
    
    func cleanup() {
        // 明示的なクリーンアップ
        arView?.session.pause()
        classificationRequest = nil
        mlModel = nil
        classificationResult = nil
        isClassificationEnabled = false
        isSetupComplete = false
        print("ARViewModel: cleanup called")
    }
    
    func setupAR() {
        print("=== setupAR関数が呼ばれました ===")
        print("ARViewModel: self = \(self)")
        print("ARViewModel: arView = \(arView)")
        print("ARViewModel: isSetupComplete = \(isSetupComplete)")
        
        // 重複実行を防止（ただし、CoreMLの再初期化は許可）
        if isSetupComplete {
            print("setupAR: 既にセットアップ済みです")
            // CoreMLの再初期化のみ実行
            print("setupCoreMLを再実行します...")
            setupCoreML()
            return
        }
        
        // 既存のセッションを停止
        arView?.session.pause()
        
        guard let arView = arView else { 
            print("ARViewModel: arView is nil")
            return 
        }
        
        // ARViewの背景を透明にしてカメラ映像を表示
        arView.backgroundColor = .clear
        
        print("ARViewModel: Setting up AR")
        print("setupCoreML will be called next...")
        
        // ARKitの可用性チェック
        guard ARWorldTrackingConfiguration.isSupported else {
            print("ARWorldTrackingConfiguration is not supported on this device")
            return
        }
        
        // AR Configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        
        // セッションの開始（例外処理付き）
        do {
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            print("ARセッションが開始されました")
        } catch {
            print("ARセッション開始エラー: \(error)")
            return
        }
        
        // Setup CoreML
        print("setupCoreMLを呼び出します...")
        setupCoreML()
        print("setupCoreMLの呼び出し完了")
        print("setupCoreML完了後のclassificationRequest状態: \(classificationRequest != nil)")
        
        // Setup frame processing
        arView.session.delegate = self
        print("ARセッションデリゲート設定完了")
        
        // セットアップ完了フラグを設定
        isSetupComplete = true
        print("setupAR: 関数の完了")
    }
    
    func setupCoreML() {
        print("=== CoreML Setup Debug ===")
        print("setupCoreML function called")
        
        // バンドル内のファイルを確認
        let bundlePath = Bundle.main.bundlePath
        print("バンドルパス: \(bundlePath)")
        
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: bundlePath)
            print("バンドル内のファイル数: \(files.count)")
            
            // CoreMLファイルを探す
            let coremlFiles = files.filter { $0.contains(".ml") }
            print("CoreMLファイル: \(coremlFiles)")
            
            // plantdoc関連ファイルを探す
            let plantdocFiles = files.filter { $0.contains("plantdoc") }
            print("plantdoc関連ファイル: \(plantdocFiles)")
            
            // すべてのファイルを表示（デバッグ用）
            print("すべてのファイル:")
            for file in files.sorted() {
                print("  - \(file)")
            }
        } catch {
            print("ファイル一覧取得エラー: \(error)")
        }
        
        // モデルファイルの読み込みを試行
        var modelURL: URL?
        
        // 1. まずmlpackageを試す（推奨）
        if let url = Bundle.main.url(forResource: "plantdoc_resnet18", withExtension: "mlpackage") {
            modelURL = url
            print("✅ mlpackageとして見つかったモデルファイル: \(url)")
        } else {
            print("❌ plantdoc_resnet18.mlpackage が見つかりません")
            
            // 2. mlmodelcを試す（フォールバック）
            if let url = Bundle.main.url(forResource: "plantdoc_resnet18", withExtension: "mlmodelc") {
                modelURL = url
                print("⚠️ mlmodelcとして見つかったモデルファイル: \(url)")
                print("⚠️ 注意: mlmodelcはコンパイル済みで、入力形式に問題がある可能性があります")
            } else {
                print("❌ plantdoc_resnet18.mlmodelc も見つかりません")
            }
        }
        
        // 3. プロジェクトディレクトリから直接読み込みを試行
        if modelURL == nil {
            print("🔄 プロジェクトディレクトリから直接読み込みを試行")
            if let projectModelPath = Bundle.main.path(forResource: "plantdoc_resnet18", ofType: "mlpackage", inDirectory: "Plantdoc-app") {
                let projectModelURL = URL(fileURLWithPath: projectModelPath)
                print("✅ プロジェクトディレクトリからモデルファイルを発見: \(projectModelURL)")
                modelURL = projectModelURL
            }
        }
        
        // 4. 絶対パスから直接読み込みを試行（開発用）
        if modelURL == nil {
            print("🔄 絶対パスから直接読み込みを試行")
            let absoluteModelPath = "/Users/doi/Desktop/Plantdoc-app/Plantdoc-app/plantdoc_resnet18.mlpackage"
            if FileManager.default.fileExists(atPath: absoluteModelPath) {
                let absoluteModelURL = URL(fileURLWithPath: absoluteModelPath)
                print("✅ 絶対パスからモデルファイルを発見: \(absoluteModelURL)")
                modelURL = absoluteModelURL
            }
        }
        
        // 5. ドキュメントディレクトリにコピーしてから読み込み
        if modelURL == nil {
            print("🔄 ドキュメントディレクトリにモデルファイルをコピーしてから読み込み")
            copyModelToDocumentsAndLoad()
            return
        }
        
        guard let finalModelURL = modelURL else {
            print("❌ CoreMLモデルファイルが見つかりません")
            print("期待されるパス: \(Bundle.main.bundlePath)/plantdoc_resnet18.mlpackage")
            print("⚠️ モデルファイルをXcodeプロジェクトに追加してください")
            print("💡 解決方法: Xcodeでプロジェクトを開き、plantdoc_resnet18.mlpackageをプロジェクトに追加してください")
            
            print("🔄 モデルファイルが見つからないため、診断機能は無効です")
            return
        }
        
        print("✅ 最終的なモデルファイルパス: \(finalModelURL)")
        
        // ファイル拡張子を確認
        if finalModelURL.pathExtension == "mlmodelc" {
            print("⚠️ mlmodelcファイルを使用します。入力形式の問題がある可能性があります。")
            print("🔄 mlmodelcファイルを直接読み込んでみます")
            // mlmodelcファイルを直接読み込む
            loadModelFromURL(finalModelURL)
            return
        }
        
        // CoreMLモデルの読み込み
        loadModelFromURL(finalModelURL)
        print("setupCoreML: 関数の完了")
    }
    
    private func loadModelFromPath(_ modelPath: URL) {
        loadModelFromURL(modelPath)
    }
    
    private func loadModelFromURL(_ modelURL: URL) {
        print("=== loadModelFromURL開始 ===")
        print("モデルURL: \(modelURL)")
        print("ファイル拡張子: \(modelURL.pathExtension)")
        
        do {
            let model = try MLModel(contentsOf: modelURL)
            print("✅ MLModel読み込み成功: \(modelURL)")
            
            // モデルの詳細情報を出力
            print("=== モデル詳細情報 ===")
            print("モデル名: \(model.modelDescription.metadata[MLModelMetadataKey.creatorDefinedKey] ?? "不明")")
            print("利用可能なメタデータキー:")
            for (key, value) in model.modelDescription.metadata {
                print("  - \(key): \(value)")
            }
            print("入力特徴量:")
            for (name, description) in model.modelDescription.inputDescriptionsByName {
                print("  - \(name): \(description)")
            }
            print("出力特徴量:")
            for (name, description) in model.modelDescription.outputDescriptionsByName {
                print("  - \(name): \(description)")
            }
            
            // Visionフレームワークの代わりにCoreMLを直接使用
            print("🔄 Visionフレームワークの代わりにCoreMLを直接使用します")
            self.mlModel = model
            
            print("✅ CoreMLモデルの読み込みに成功しました: \(modelURL)")
            print("✅ mlModel初期化完了: \(mlModel != nil)")
            print("=== loadModelFromURL完了 ===")
        } catch {
            print("❌ CoreMLモデルの読み込みに失敗しました: \(error)")
            print("モデルパス: \(modelURL)")
            print("エラー詳細: \(error.localizedDescription)")
            print("エラータイプ: \(type(of: error))")
            
            // エラーの場合は診断機能を無効にする
            print("🔄 エラーのため診断機能を無効にします")
            DispatchQueue.main.async {
                self.classificationResult = ClassificationResult(
                    className: "モデル読み込みエラー",
                    confidence: 0.0
                )
            }
        }
    }
    

    

    
    private func copyModelToDocumentsAndLoad() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("ドキュメントディレクトリが見つかりません")
            return
        }
        
        let modelPath = documentsPath.appendingPathComponent("plantdoc_resnet18.mlpackage")
        let sourcePath = "/Users/doi/Desktop/Plantdoc-app/Plantdoc-app/plantdoc_resnet18.mlpackage"
        
        print("ドキュメントディレクトリ: \(documentsPath)")
        print("モデルパス: \(modelPath)")
        print("ソースパス: \(sourcePath)")
        print("ソースファイル存在: \(FileManager.default.fileExists(atPath: sourcePath))")
        
        // 既にドキュメントディレクトリにあるかチェック
        if FileManager.default.fileExists(atPath: modelPath.path) {
            print("✅ ドキュメントディレクトリにモデルファイルが既に存在します")
            loadModelFromURL(modelPath)
            return
        }
        
        // ファイルをコピー
        do {
            try FileManager.default.copyItem(atPath: sourcePath, toPath: modelPath.path)
            print("✅ モデルファイルをドキュメントディレクトリにコピーしました")
            loadModelFromURL(modelPath)
        } catch {
            print("❌ モデルファイルのコピーに失敗しました: \(error)")
            print("エラー詳細: \(error.localizedDescription)")
            // コピーに失敗した場合は診断機能を無効にする
            DispatchQueue.main.async {
                self.classificationResult = ClassificationResult(
                    className: "モデルファイルコピーエラー",
                    confidence: 0.0
                )
            }
        }
    }
    
    func processClassification(request: VNRequest, error: Error?) {
        print("processClassification呼び出し")
        
        if let error = error {
            print("推論エラー: \(error)")
            return
        }
        
        guard let results = request.results as? [VNClassificationObservation] else {
            print("推論結果の型変換に失敗")
            return
        }
        
        print("推論結果数: \(results.count)")
        
        // 上位5件の結果を表示
        for (index, result) in results.prefix(5).enumerated() {
            print("結果\(index + 1): \(result.identifier) (信頼度: \(result.confidence))")
        }
        
        guard let topResult = results.first else {
            print("推論結果が取得できませんでした")
            // シミュレータ用のメッセージ
            #if targetEnvironment(simulator)
            DispatchQueue.main.async {
                self.classificationResult = ClassificationResult(
                    className: "シミュレータでは診断できません",
                    confidence: 0.0
                )
                print("シミュレータ用メッセージを設定")
            }
            #endif
            return
        }
        
        print("最上位推論結果: \(topResult.identifier) (信頼度: \(topResult.confidence))")
        
        // 信頼度が0.3未満の場合は結果を表示しない（閾値を下げる）
        guard topResult.confidence > 0.3 else {
            print("信頼度が低すぎます: \(topResult.confidence)")
            DispatchQueue.main.async {
                self.classificationResult = ClassificationResult(
                    className: "認識できません",
                    confidence: topResult.confidence
                )
            }
            return
        }
        
        // メインスレッドでの更新を最適化
        DispatchQueue.main.async {
            self.classificationResult = ClassificationResult(
                className: topResult.identifier,
                confidence: topResult.confidence
            )
            print("診断結果を更新: \(topResult.identifier)")
        }
    }
    
    func resetSession() {
        guard let arView = arView else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        classificationResult = nil
    }
    
    // 画像の前処理（224x224にリサイズ）
    private func preprocessImage(pixelBuffer: CVPixelBuffer) -> MLMultiArray? {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        // CIImageに変換
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 224x224にリサイズ
        let scale = min(224.0 / CGFloat(width), 224.0 / CGFloat(height))
        let scaledImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // 中央を224x224でクロップ
        let cropRect = CGRect(x: (scaledImage.extent.width - 224) / 2,
                             y: (scaledImage.extent.height - 224) / 2,
                             width: 224, height: 224)
        let croppedImage = scaledImage.cropped(to: cropRect)
        
        // MLMultiArrayに変換
        do {
            let array = try MLMultiArray(shape: [1, 3, 224, 224], dataType: .float16)
            
            // 画像データを配列にコピー（簡略化）
            // 実際の実装では、ピクセル値を正規化して配列に格納する必要があります
            
            return array
        } catch {
            print("MLMultiArray作成エラー: \(error)")
            return nil
        }
    }
    
    // CoreML推論結果の処理
    private func processCoreMLPrediction(prediction: MLFeatureProvider) {
        guard let output = prediction.featureValue(for: "var_362")?.multiArrayValue else {
            print("推論結果の取得に失敗")
            return
        }
        
        // 出力配列から最大値のインデックスを取得
        var maxIndex = 0
        var maxValue: Float = -Float.infinity
        
        for i in 0..<output.count {
            let value = output[i].floatValue
            if value > maxValue {
                maxValue = value
                maxIndex = i
            }
        }
        
        // クラス名の配列（実際のモデルに合わせて調整）
        let classNames = [
            "健康な植物", "病気の植物", "葉の斑点", "根の腐敗", "茎の病気",
            "花の病気", "果実の病気", "種子の病気", "芽の病気", "枝の病気"
        ]
        
        let className = maxIndex < classNames.count ? classNames[maxIndex] : "不明なクラス"
        let confidence = maxValue / 100.0 // 簡略化
        
        print("推論結果: \(className) (信頼度: \(confidence))")
        
        DispatchQueue.main.async {
            self.classificationResult = ClassificationResult(
                className: className,
                confidence: confidence
            )
        }
    }
}

// AR Session Delegate
extension ARViewModel: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isClassificationEnabled else {
            return
        }
        
        guard let model = mlModel else {
            print("mlModelがnilです")
            print("mlModel初期化状態: \(mlModel != nil)")
            print("setupCoreMLが呼ばれているか確認してください")
            print("isSetupComplete: \(isSetupComplete)")
            print("setupARが呼ばれているか確認してください")
            // モデルが読み込まれていない場合の処理
            DispatchQueue.main.async {
                self.classificationResult = ClassificationResult(
                    className: "モデル未読み込み",
                    confidence: 0.0
                )
            }
            return
        }
        
        // フレーム処理の間隔を2秒に延長
        guard Date().timeIntervalSince(lastClassificationTime) > 2.0 else {
            return
        }
        
        print("フレーム処理開始: isClassificationEnabled=\(isClassificationEnabled)")
        print("mlModel状態: \(mlModel != nil)")
        lastClassificationTime = Date()
        
        let pixelBuffer = frame.capturedImage
        
        // バックグラウンドで画像処理
        DispatchQueue.global(qos: .userInitiated).async {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            print("画像サイズ: \(width) x \(height)")
            
            // 画像を224x224にリサイズして前処理
            guard let resizedImage = self.preprocessImage(pixelBuffer: pixelBuffer) else {
                print("画像の前処理に失敗しました")
                return
            }
            
            do {
                // CoreMLモデルで推論実行
                let input = try MLDictionaryFeatureProvider(dictionary: ["x_1": resizedImage])
                let prediction = try model.prediction(from: input)
                print("推論リクエスト実行完了")
                
                // 結果を処理
                self.processCoreMLPrediction(prediction: prediction)
            } catch {
                print("推論エラー: \(error)")
                DispatchQueue.main.async {
                    self.classificationResult = ClassificationResult(
                        className: "推論エラー",
                        confidence: 0.0
                    )
                }
            }
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("ARセッションエラー: \(error)")
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("ARセッションが中断されました")
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("ARセッションの中断が終了しました")
    }
}

#Preview {
    ContentView()
}

