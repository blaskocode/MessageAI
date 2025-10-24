/**
 * ChatViewModel+Testing - Phase 2 Backend Testing
 * Test functions for PRs #4-9 Cloud Functions
 */

import Foundation

extension ChatViewModel {
    
    // MARK: - Phase 2 Testing Functions
    
    /// Run all Phase 2 backend tests (PRs #4-9)
    func runAllPhase2Tests() async {
        print("\n🧪 ========================================")
        print("🧪 PHASE 2 BACKEND TESTING (PRs #4-9)")
        print("🧪 ========================================\n")
        
        await testPR4_FormalityAnalysis()
        await testPR4_FormalityAdjustment()
        
        print("\n🧪 ========================================")
        print("🧪 ALL TESTS COMPLETE")
        print("🧪 Check results above ☝️")
        print("🧪 ========================================\n")
    }
    
    // MARK: - PR #4: Formality Analysis Tests
    
    func testPR4_FormalityAnalysis() async {
        print("📊 TEST: PR #4 - Formality Analysis")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Test 1: Spanish Formal (usted)
        print("\n1️⃣ Spanish Formal (usted)...")
        do {
            let analysis = try await aiService.analyzeFormalityAnalysis(
                messageId: "test_es_formal_\(UUID().uuidString)",
                text: "Buenos días. ¿Podría usted ayudarme, por favor?",
                language: "es"
            )
            print("✅ SUCCESS")
            print("   Level: \(analysis.level.displayName) \(analysis.level.emoji)")
            print("   Confidence: \(Int(analysis.confidence * 100))%")
            print("   Markers: \(analysis.markers.count) detected")
            if !analysis.markers.isEmpty {
                print("   Example: \"\(analysis.markers.first?.text ?? "")\"")
            }
            print("   Explanation: \(analysis.explanation.prefix(80))...")
        } catch {
            print("❌ FAILED: \(error.localizedDescription)")
        }
        
        // Test 2: Spanish Casual (tú)
        print("\n2️⃣ Spanish Casual (tú)...")
        do {
            let analysis = try await aiService.analyzeFormalityAnalysis(
                messageId: "test_es_casual_\(UUID().uuidString)",
                text: "¿Cómo estás? ¿Quieres ir al cine esta noche?",
                language: "es"
            )
            print("✅ SUCCESS")
            print("   Level: \(analysis.level.displayName) \(analysis.level.emoji)")
            print("   Confidence: \(Int(analysis.confidence * 100))%")
        } catch {
            print("❌ FAILED: \(error.localizedDescription)")
        }
        
        // Test 3: German Formal (Sie)
        print("\n3️⃣ German Formal (Sie)...")
        do {
            let analysis = try await aiService.analyzeFormalityAnalysis(
                messageId: "test_de_formal_\(UUID().uuidString)",
                text: "Guten Tag, könnten Sie mir bitte helfen?",
                language: "de"
            )
            print("✅ SUCCESS")
            print("   Level: \(analysis.level.displayName) \(analysis.level.emoji)")
            print("   Confidence: \(Int(analysis.confidence * 100))%")
        } catch {
            print("❌ FAILED: \(error.localizedDescription)")
        }
        
        // Test 4: German Casual (du)
        print("\n4️⃣ German Casual (du)...")
        do {
            let analysis = try await aiService.analyzeFormalityAnalysis(
                messageId: "test_de_casual_\(UUID().uuidString)",
                text: "Hey, kommst du heute Abend mit?",
                language: "de"
            )
            print("✅ SUCCESS")
            print("   Level: \(analysis.level.displayName) \(analysis.level.emoji)")
            print("   Confidence: \(Int(analysis.confidence * 100))%")
        } catch {
            print("❌ FAILED: \(error.localizedDescription)")
        }
        
        // Test 5: Cache Test (same message twice)
        print("\n5️⃣ Cache Test (timing comparison)...")
        let testMessageId = "test_cache_\(UUID().uuidString)"
        let testText = "How are you doing today?"
        
        // First call (no cache)
        let start1 = Date()
        do {
            _ = try await aiService.analyzeFormalityAnalysis(
                messageId: testMessageId,
                text: testText,
                language: "en"
            )
            let duration1 = Date().timeIntervalSince(start1)
            print("   First call: \(String(format: "%.2f", duration1))s")
            
            // Second call (should be cached)
            let start2 = Date()
            _ = try await aiService.analyzeFormalityAnalysis(
                messageId: testMessageId,
                text: testText,
                language: "en"
            )
            let duration2 = Date().timeIntervalSince(start2)
            print("   Second call: \(String(format: "%.2f", duration2))s")
            
            if duration2 < duration1 * 0.3 {
                print("✅ CACHE WORKING (2nd call \(Int((1 - duration2/duration1) * 100))% faster)")
            } else {
                print("⚠️ Cache might not be working properly")
            }
        } catch {
            print("❌ FAILED: \(error.localizedDescription)")
        }
        
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    func testPR4_FormalityAdjustment() async {
        print("📊 TEST: PR #4 - Formality Adjustment")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // Test 1: English Casual → Formal
        print("\n1️⃣ English: Casual → Formal...")
        do {
            let adjustment = try await aiService.adjustFormality(
                text: "Hey, what's up? Wanna grab lunch?",
                currentLevel: nil,  // Auto-detect
                targetLevel: .formal,
                language: "en"
            )
            print("✅ SUCCESS")
            print("   Original: \"\(adjustment.originalText)\"")
            print("   Adjusted: \"\(adjustment.adjustedText)\"")
            print("   \(adjustment.originalLevel.emoji) → \(adjustment.targetLevel.emoji)")
            print("   Changes: \(adjustment.changesExplanation.prefix(100))...")
        } catch {
            print("❌ FAILED: \(error.localizedDescription)")
        }
        
        // Test 2: Spanish Formal → Casual
        print("\n2️⃣ Spanish: Formal → Casual...")
        do {
            let adjustment = try await aiService.adjustFormality(
                text: "Buenos días. ¿Podría usted ayudarme?",
                currentLevel: .formal,
                targetLevel: .casual,
                language: "es"
            )
            print("✅ SUCCESS")
            print("   Original: \"\(adjustment.originalText)\"")
            print("   Adjusted: \"\(adjustment.adjustedText)\"")
            print("   Expected: usted → tú change")
        } catch {
            print("❌ FAILED: \(error.localizedDescription)")
        }
        
        // Test 3: Preserve Meaning Test
        print("\n3️⃣ Meaning Preservation Test...")
        do {
            let original = "I'm really excited about the project deadline next week!"
            let adjustment = try await aiService.adjustFormality(
                text: original,
                currentLevel: nil,
                targetLevel: .veryFormal,
                language: "en"
            )
            print("✅ SUCCESS")
            print("   Original: \"\(original)\"")
            print("   Very Formal: \"\(adjustment.adjustedText)\"")
            print("   Check: Should preserve excitement about deadline")
        } catch {
            print("❌ FAILED: \(error.localizedDescription)")
        }
        
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
}

