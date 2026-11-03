import {defineString} from "firebase-functions/params";
import {Breakdown} from "./fees.js";

/**
 * Where escrow actually happens. The Runner never holds customer money
 * itself; a provider does, and releases it on our signal.
 *
 * ESCROW_PROVIDER selects the implementation:
 *   - "fake" (default): no real money. startPayment marks the errand
 *     funded straight away, so the whole flow can be tested in the
 *     emulator and on test phones before TradeSafe access is set up.
 *   - "tradesafe": the real thing (see TradeSafeProvider below).
 *
 * Set it by putting ESCROW_PROVIDER=tradesafe in
 * functions/.env.<project-id>.
 */
const providerName = defineString("ESCROW_PROVIDER", {default: "fake"});

export interface CreatePaymentInput {
  errandId: string;
  title: string;
  requesterUid: string;
  runnerUid: string;
  money: Breakdown;
}

export interface EscrowProvider {
  readonly name: string;

  /**
   * Opens an escrow transaction and returns where the requester pays.
   * [fundedImmediately] is true only for the fake provider.
   */
  createPayment(input: CreatePaymentInput): Promise<{
    providerRef: string;
    paymentUrl: string;
    fundedImmediately: boolean;
  }>;

  /** Pays the runner (fee - 5% + purchase money) and refunds any unspent budget. */
  release(providerRef: string, money: Breakdown): Promise<void>;

  /** Returns everything held to the requester. */
  refund(providerRef: string): Promise<void>;
}

class FakeProvider implements EscrowProvider {
  readonly name = "fake";

  async createPayment(input: CreatePaymentInput) {
    console.log(`[fake escrow] ${input.errandId}: holding R${input.money.requesterTotal}`);
    return {
      providerRef: `fake_${input.errandId}`,
      paymentUrl: "https://example.com/fake-escrow-paid",
      fundedImmediately: true,
    };
  }

  async release(providerRef: string, money: Breakdown) {
    console.log(`[fake escrow] ${providerRef}: released`, money);
  }

  async refund(providerRef: string) {
    console.log(`[fake escrow] ${providerRef}: refunded`);
  }
}

/**
 * TradeSafe (https://www.tradesafe.co.za), Standard Bank-backed SA
 * escrow with an API.
 *
 * TODO(tradesafe): wire this up once API access is confirmed. Before
 * writing it, confirm with TradeSafe:
 *   - marketplace/agent setup, so The Runner's 10% is paid out
 *     automatically as an agent fee
 *   - hold, release, partial release and refund
 *   - payouts to any SA bank account (runners)
 *   - how the payment-confirmed webhook is signed, so
 *     tradesafeWebhook can verify it
 *   - per-transaction fees (absorbed from the 10%)
 * Credentials belong in Secret Manager (defineSecret), never in code.
 */
class TradeSafeProvider implements EscrowProvider {
  readonly name = "tradesafe";

  async createPayment(): Promise<{
    providerRef: string;
    paymentUrl: string;
    fundedImmediately: boolean;
  }> {
    throw new Error("TradeSafe is not connected yet");
  }

  async release(): Promise<void> {
    throw new Error("TradeSafe is not connected yet");
  }

  async refund(): Promise<void> {
    throw new Error("TradeSafe is not connected yet");
  }
}

export function escrow(): EscrowProvider {
  return providerName.value() === "tradesafe" ? new TradeSafeProvider() : new FakeProvider();
}
