//
//  KafeCamTests.swift
//  KafeCamTests
//
//  Created by Grecia Saucedo on 06/09/25.
//

import Foundation
import Testing
@testable import KafeCam

struct KafeCamTests {

    @Test func testDiseaseJSONLoadingAndDecoding() throws {
        // Check if the "diseases.json" file can be loaded
        // and decoded into an array of DiseaseModel objects.

        let loadedDiseases = diseases
        
        // Check that the array is not empty.
        #expect(loadedDiseases.isEmpty == false, "The diseases array should not be empty.")
        
        
        // Check that all decoded items have a valid UUID.
        for disease in loadedDiseases {
            #expect(disease.id != UUID(), "Disease '\(disease.name)' should have a valid, non-zero UUID.")
        }
    }

    @Test func testDiseaseModelOptionalScientificName() throws {
        // Check that the optional 'scientificName' property
        // is correctly decoded: holding a value when present in the JSON
        // and being 'nil' when absent.
        
        // Get the loaded data
        let loadedDiseases = diseases
        
        // Find the "Roya" item, which should have a scientific name.
        let roya = loadedDiseases.first { $0.name == "Roya del Café" }
        
        #expect(roya != nil, "Could not find 'Roya del Café' in the loaded data.")
        #expect(roya?.scientificName == "Hemileia vastatrix", "Roya's scientific name is incorrect or nil.")
        
        // Find the "Nitrógeno" item, which should not have a scientific name.
        let nitrogeno = loadedDiseases.first { $0.name == "Deficiencia de Nitrógeno" }
        
        #expect(nitrogeno != nil, "Could not find 'Deficiencia de Nitrógeno' in the loaded data.")
        #expect(nitrogeno?.scientificName == nil, "Nitrógeno's scientific name should be nil.")
    }

}
