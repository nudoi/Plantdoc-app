//
//  Plantdoc_appTests.swift
//  Plantdoc-appTests
//
//  Created by GitHub Actions on 2025/07/16.
//

import XCTest
@testable import Plantdoc_app

final class Plantdoc_appTests: XCTestCase {
    
    var arViewModel: ARViewModel!
    
    override func setUpWithError() throws {
        arViewModel = ARViewModel()
    }
    
    override func tearDownWithError() throws {
        arViewModel = nil
    }
    
    func testARViewModelInitialization() throws {
        // ARViewModelが正しく初期化されることをテスト
        XCTAssertNotNil(arViewModel)
        XCTAssertFalse(arViewModel.isClassificationEnabled)
        XCTAssertNil(arViewModel.classificationResult)
        XCTAssertFalse(arViewModel.isSetupComplete)
    }
    
    func testClassificationResultStructure() throws {
        // ClassificationResultの構造をテスト
        let result = ARViewModel.ClassificationResult(
            className: "健康な植物",
            confidence: 0.95
        )
        
        XCTAssertEqual(result.className, "健康な植物")
        XCTAssertEqual(result.confidence, 0.95)
    }
    
    func testCleanupFunction() throws {
        // cleanup関数が正しく動作することをテスト
        arViewModel.isClassificationEnabled = true
        arViewModel.classificationResult = ARViewModel.ClassificationResult(
            className: "テスト",
            confidence: 0.5
        )
        arViewModel.isSetupComplete = true
        
        arViewModel.cleanup()
        
        XCTAssertFalse(arViewModel.isClassificationEnabled)
        XCTAssertNil(arViewModel.classificationResult)
        XCTAssertFalse(arViewModel.isSetupComplete)
    }
    
    func testResetSession() throws {
        // resetSession関数が正しく動作することをテスト
        arViewModel.classificationResult = ARViewModel.ClassificationResult(
            className: "テスト",
            confidence: 0.5
        )
        
        arViewModel.resetSession()
        
        XCTAssertNil(arViewModel.classificationResult)
    }
    
    func testPerformanceExample() throws {
        // パフォーマンステスト
        measure {
            // 重い処理をここに配置
            for _ in 0..<1000 {
                let _ = ARViewModel.ClassificationResult(
                    className: "テスト",
                    confidence: 0.5
                )
            }
        }
    }
}
