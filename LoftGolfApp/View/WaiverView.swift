import SwiftUI

struct WaiverView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var agreed = false
    @State private var signedName = ""
    @State private var showError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Participant Waiver and Release of Liability")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)
                
                Text("""
                PARTICIPANT WAIVER AND RELEASE OF LIABILITY
                I, the undersigned participant, hereby acknowledge and agree to the terms and conditions set forth in this Participant Waiver and Release of Liability (the "Waiver") in consideration of being permitted to use the indoor golf simulator and related equipment at Loft Golf Studios (the "Facility").

                WAIVER AND RELEASE OF LIABILITY (Agreement):
                1. Assumption of Risk: I understand that using the indoor golf simulator involves inherent risks, including but not limited to the risk of injury, property damage, or other losses. I acknowledge that playing golf involves physical exertion and may require precise movements, and I voluntarily assume all such risks associated with my use of the indoor golf simulator.

                2. Release and Waiver: In consideration of being allowed to use the indoor golf simulator and related equipment, I, on behalf of myself and my heirs, executors, administrators, and assigns, do hereby release and forever discharge Loft Golf Studios, its owners, employees, agents, contractors, and representatives (collectively referred to as "Released Parties"), from any and all claims, demands, actions, causes of action, suits, liabilities, obligations, judgments, and liabilities of any kind, whether at law or in equity, arising out of or relating to any personal injury, property damage, or other loss that may result from my use of the indoor golf simulator, including but not limited to claims for negligence, premises liability, and breach of warranty.

                3. Indemnification: I agree to indemnify, defend, and hold harmless the Released Parties from and against any and all claims, demands, actions, suits, liabilities, judgments, costs, expenses, and attorneys' fees arising out of or in connection with my use of the indoor golf simulator, whether or not caused by the negligence of the Released Parties.

                4. Medical Condition: I hereby represent that I am in good health and physical condition and that I have no medical condition that would prevent me from safely using the indoor golf simulator. I understand that it is my responsibility to consult with a medical professional before using the indoor golf simulator if I have any concerns about my health or physical condition.

                5. Use of Facility: I agree to use the indoor golf simulator and related equipment in a safe and responsible manner. I will follow all posted rules, guidelines, and instructions provided by the Facility's staff.  I will be personally liable for any and all damage and to the building, simulators, and related equipment caused by my careless, reckless or intentional actions.  I understand that repairs and cleaning fees may be charged to the credit card on file to cover these costs.  At any time Loft Golf Studios may suspend or revoke booking privileges due to failure to comply to the rules, guidelines and instructions set forth.

                6. Severability: If any provision of this Waiver is deemed invalid or unenforceable, the remaining provisions shall remain in full force and effect.

                GENERAL PROVISIONS:
                1. I hereby expressly agree that (1) this Agreement shall be governed and construed according to the laws of the state of Arizona without regard to its conflict of laws provisions and (2) any action or proceeding concerning any Claim or the meaning or effect of any provision of the Agreement shall be conducted only in the state courts located in Maricopa County, Arizona, and that for such purposes, I expressly submit to the jurisdiction of such courts.

                2. This Agreement contains the entire understanding between and among the parties concerning these matters. No waiver, modification, or amendment of any of the terms of this Agreement shall be effective unless made in writing and signed by the party to be charged.

                3. I hereby expressly agree that if any portion of this Agreement is held invalid, the balance of the Agreement shall nonetheless continue in full legal force and effect. I warrant that I have read and understand that this Agreement involves my waiver and release of significant rights and my assumption of significant indemnification responsibilities in participating in the Event.

                VENUE SAFETY RULES AND REGULATIONS:
                I agree to follow procedures and safety rules described in the Rules and Regulations (available on the Loft Golf Studios website), which are intended to protect the players, spectators and other guests.

                LIABILITY WAIVER ON BEHALF OF GUESTS:

                I represent that I will be responsible for any and all guests in my party that are not registered guests or members at Loft Golf Studios.  I agree to make known to all guests the details set forth in this Agreement and ensure understanding, acceptance and compliance by all guests.  I further agree to be legally bound by the provisions of this Agreement and to indemnify and hold harmless The Released And Indemnified Parties for any claims that the guests may now have or may arise in the future during the Claim Period against any of The Released And Indemnified Parties arising on the Premises.

                RULES AND REGULATIONS:
                1. Please ensure you have CLEAN SHOES and CLEAN CLUBS and ALWAYS USE UNDAMAGED CLEAN GOLF BALLS WITHOUT PEN MARKINGS.
                    1. In order to keep the simulator screen looking the best it can for the sake of all users, please ensure that you clean your golf clubs prior to using the simulator.
                    2. Loft Golf Studios provides an area to clean your clubs prior to entering the facility if necessary.
                    3. Use ONLY CLEAN UNDAMAGED CLEAN GOLF BALLS WITHOUT PEN MARKINGS.
                    4. Pen markings will transfer to the screen and nicks and cuts on the golf balls which can cause unrepairable damage to the screen.
                2. Keep food and drinks at the provided seating area and tables. NO FOOD OR DRINK IN THE SIMULATOR HITTING AREA at any time.
                    1. No persons under the age of 21 may consume alcohol at any time while on the Loft Golf Studios premises.
                3. No smoking or vaping inside the facility or within 50' of doorways.
                4. Be respectful of other guests, members and employees.
                5.  Must be at least 18 years of age to book a reservation at Loft Golf Studios.
                    1. Must have a legal adult present in the facility at all times during the reservation.
                    2. No children under the age of 10 without supervision from a non-golfing adult.
                6. Players are responsible for the equipment inside the simulator. No swinging clubs outside of the simulator hitting area for safety reasons.
                7. Only one person should be present in the hitting area at a time. Everyone MUST keep a safe distance, and keep watch of the person golfing.
                8. Before you swing any club, check your surroundings to ensure no one or obstacle is within your range of swing.
                9. Be aware of your backswing and follow-through at all times.
                10. Your shot must always be directed towards the hitting screen.
                11. Swinging should always take place near the hitting area of the mat.
                12. Be alert of where you stand or walk and stay out of someone’s range of swing.
                13. Report any accidents immediately.
                14. Customers are financially responsible for any damage caused by failure to follow the directions of the Rules and Regulations.
                15. Customers acknowledge Loft Golf Studios is under video surveillance. Tampering with a camera system or damaging equipment by not following procedures in the guidelines will result in financial compensation being paid to Loft Golf Studios.
                16. Customers acknowledge that photography and/or video may be recorded and used for promotional purposes without compensation.
                17. Customers are responsible for reviewing the simulator system operation at https://loftgolfstudios.com/simulator-how-to which will be reviewed during your initial visit.
                    1. As with all technology, there is a learning curve associated with any new software, please review the reference material provided to assist in learning to use the simulator software.
                    2. Occasionally there will be anomalies where the software does not operate as expected, refer to the support and troubleshooting guides for reference.
                    3. Phone and text support is available during specific hours as posted at the facility.  If you experience technology issues outside of this time during your appointment, send an email to info@loftgolfstudios.com and we will contact you at our earliest convenience to address the issue.
                18. We would love for you to be able to finish your “last hole”; however, all groups must gather all personal belongings, clean up any and discard all waste generated and leave the simulator bay 5 minutes prior to the incoming group start time.  The transition to the next group should be such that the incoming group can start promptly at their scheduled start time.  You should not still be using the simulator or gathering your belongings during the incoming group's session time.
                19. Failure to abide by any of the above procedures may result in the cancellation of the remainder of your paid simulator time without compensation.  Multiple offenses may also include account cancellation and loss of future booking privileges at Loft Golf Studios.
                
                I HAVE READ THIS RELEASE AGREEMENT, FULLY UNDERSTAND ITS TERMS, UNDERSTAND THAT I AM GIVING UP SUBSTANTIAL RIGHTS BY ENTERING THIS FACILITY AND DO SO FREELY AND VOLUNTARILY WITHOUT ANY INDUCEMENT.

                I HEREBY ACKNOWLEDGE (1) THAT THIS DOCUMENT IS VALID AND MAY BE ENFORCED IN THE SAME MANNER AS A HAND-SIGNED DOCUMENT THAT EXISTS IN PHYSICAL FORM. I ALSO EXPRESSLY ACKNOWLEDGE THE VALIDITY OF THIS DOCUMENT. I FURTHER AGREE THAT I HAVE KNOWINGLY AND EXPLICITLY WAIVED ANY RIGHT TO CLAIM THIS DOCUMENT IS INVALID OR IS UNENFORCEABLE BASED ON THE FACT THAT I HAVE NOT PUT PEN TO PAPER.

                I have carefully read and understood this Waiver and Release of Liability, and I voluntarily agree to its terms. I acknowledge that by signing this Waiver, I am giving up certain legal rights, including the right to sue the Released Parties for any claims arising from my use of the indoor golf simulator.
                """)
                .foregroundStyle(.white.opacity(0.9))
                .font(.body)
                .multilineTextAlignment(.leading)
                .padding(.bottom, 20)

                Toggle(isOn: $agreed) {
                    Text("I have read and agree to the terms above.")
                        .foregroundStyle(.white)
                }

                TextField("Type full name as signature", text: $signedName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 10)

                Button {
                    if agreed && !signedName.isEmpty {
                        // Save waiver status, then go to main app
                        dismiss()
                    } else {
                        showError = true
                    }
                } label: {
                    Text("Agree and Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(agreed && !signedName.isEmpty ? Color.white : Color.gray)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                }
                .disabled(!agreed || signedName.isEmpty)

                if showError {
                    Text("Please agree and sign before continuing.")
                        .foregroundColor(.red)
                        .font(.footnote)
                }
            }
            .padding()
        }
        .background(Color(red: 0.10, green: 0.11, blue: 0.14).ignoresSafeArea())
        .navigationTitle("Waiver Form")
    }
}
