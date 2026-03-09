// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title StakingPool
 * @dev   Multi-pool staking contract for the Mogaland ecosystem.
 *        Supports native ETH, ERC-20 tokens (MOGA, wMOGA, USDC …), and LP tokens
 *        (Aerodrome / Camelot / Uniswap V3 LP positions).
 *
 * Pool types
 * ──────────
 *  • ETH pool    – stakingToken = address(0); user calls stake(poolId, 0) with msg.value
 *  • ERC-20 pool – stakingToken = token address; user approves then calls stake(poolId, amount)
 *  • LP pool     – same as ERC-20 pool; stakingToken is a DEX LP token
 *  • wMOGA pool  – same as ERC-20 pool; stakingToken = wMOGA contract address
 *
 * Reward model
 * ────────────
 *  Each pool emits `rewardRate` reward-tokens per second, shared proportionally
 *  among all stakers (standard "reward-per-token accumulator" design).
 *
 * Deployment – Target Networks
 * ────────────────────────────
 *  Deploy on each of the following networks via Remix IDE:
 *    ┌──────────────────┬───────────────────────────────────────────────────────┐
 *    │ Network          │ Notes                                                 │
 *    ├──────────────────┼───────────────────────────────────────────────────────┤
 *    │ Base mainnet     │ USDC 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913      │
 *    │                  │ WETH 0x4200000000000000000000000000000000000006        │
 *    ├──────────────────┼───────────────────────────────────────────────────────┤
 *    │ Arbitrum One     │ USDC 0xaf88d065e77c8cC2239327C5EDb3A432268e5831       │
 *    │                  │ WETH 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1       │
 *    ├──────────────────┼───────────────────────────────────────────────────────┤
 *    │ EDU Chain        │ use wrapped versions of the above tokens or            │
 *    │ (testnet)        │ deploy ERC-20 test tokens for reward                  │
 *    ├──────────────────┼───────────────────────────────────────────────────────┤
 *    │ Base Sepolia     │ Testnet only – for integration testing                 │
 *    └──────────────────┴───────────────────────────────────────────────────────┘
 *
 *  Steps:
 *  1. Deploy wMOGA.sol, passing the deployed MOGA address to the constructor.
 *  2. Deploy this contract.
 *  3. Fund the contract with reward tokens.
 *  4. Call addPool() for each pool (name, stakingToken, rewardToken, rate):
 *       – ETH pool:        addPool("ETH Stake",          address(0),   <reward>, <rate>)
 *       – USDC pool:       addPool("USDC Stake",         <USDC>,       <reward>, <rate>)
 *       – MOGA pool:       addPool("MOGA Stake",         <MOGA>,       <reward>, <rate>)
 *       – wMOGA pool:      addPool("wMOGA Stake",        <wMOGA>,      <reward>, <rate>)
 *       – wMOGA/USDC LP:   addPool("wMOGA/USDC LP",      <LP_addr>,    <reward>, <rate>)
 *       – wMOGA/ETH LP:    addPool("wMOGA/ETH LP",       <LP_addr>,    <reward>, <rate>)
 *  5. After deployment, update `index.html`: set `stakingContractAddress` in the
 *     appropriate network entry inside the NETWORKS map.
 */
contract StakingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ─── Data structures ─────────────────────────────────────────────────────

    struct Pool {
        IERC20   stakingToken;          // address(0) → native ETH; otherwise ERC-20 / LP
        IERC20   rewardToken;           // ERC-20 token paid out as reward
        uint256  totalStaked;           // Aggregate tokens locked in this pool
        uint256  rewardRate;            // Reward tokens emitted per second (in rewardToken wei)
        uint256  lastUpdateTime;        // Timestamp of the last rewardPerToken checkpoint
        uint256  rewardPerTokenStored;  // Cumulative reward-per-staked-token × 1e18
        string   name;                  // Human-readable label shown in the UI
    }

    struct UserInfo {
        uint256 amountStaked; // User's deposited amount
        uint256 rewardDebt;   // amountStaked × rewardPerTokenStored / 1e18 at last checkpoint
    }

    // ─── State ───────────────────────────────────────────────────────────────

    mapping(uint256 => Pool)                        public pools;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public poolCount;

    // ─── Events ──────────────────────────────────────────────────────────────

    event PoolAdded(
        uint256 indexed poolId,
        string  name,
        address stakingToken,
        address rewardToken,
        uint256 rewardRate
    );
    event Staked(address indexed user, uint256 indexed poolId, uint256 amount);
    event Unstaked(address indexed user, uint256 indexed poolId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 indexed poolId, uint256 amount);
    event RewardRateUpdated(uint256 indexed poolId, uint256 newRewardRate);
    event PoolNameUpdated(uint256 indexed poolId, string newName);

    // ─── Constructor ─────────────────────────────────────────────────────────

    constructor() Ownable(msg.sender) {}

    // ─── Owner: pool management ──────────────────────────────────────────────

    /**
     * @notice Add a new staking pool.
     * @param name          Human-readable label (e.g. "wMOGA/USDC LP").
     * @param stakingToken  address(0) for ETH pool; ERC-20 or LP token address otherwise.
     * @param rewardToken   ERC-20 token paid out as reward. Must not be address(0).
     * @param rewardRate    Reward tokens emitted per second (in rewardToken wei, e.g. 1e15
     *                      equals 0.001 tokens/s for an 18-decimal reward token).
     */
    function addPool(
        string calldata name,
        address stakingToken,
        address rewardToken,
        uint256 rewardRate
    ) external onlyOwner {
        require(rewardToken != address(0), "StakingPool: invalid reward token");
        require(rewardRate > 0,            "StakingPool: rewardRate must be > 0");

        ++poolCount;
        uint256 poolId = poolCount;

        pools[poolId] = Pool({
            stakingToken:         IERC20(stakingToken),
            rewardToken:          IERC20(rewardToken),
            totalStaked:          0,
            rewardRate:           rewardRate,
            lastUpdateTime:       block.timestamp,
            rewardPerTokenStored: 0,
            name:                 name
        });

        emit PoolAdded(poolId, name, stakingToken, rewardToken, rewardRate);
    }

    /**
     * @notice Update the human-readable name of a pool (owner only).
     */
    function setPoolName(uint256 poolId, string calldata newName) external onlyOwner {
        require(bytes(newName).length > 0,                                    "StakingPool: name cannot be empty");
        require(address(pools[poolId].rewardToken) != address(0), "StakingPool: pool not found");
        pools[poolId].name = newName;
        emit PoolNameUpdated(poolId, newName);
    }

    /**
     * @notice Update the emission rate of an existing pool (owner only).
     *         Triggers a rewardPerToken checkpoint before the change takes effect.
     */
    function setRewardRate(uint256 poolId, uint256 newRewardRate) external onlyOwner {
        require(newRewardRate > 0, "StakingPool: rewardRate must be > 0");
        _updatePool(poolId);
        pools[poolId].rewardRate = newRewardRate;
        emit RewardRateUpdated(poolId, newRewardRate);
    }

    // ─── Internal: reward accounting ─────────────────────────────────────────

    function _updatePool(uint256 poolId) internal {
        Pool storage pool = pools[poolId];
        if (block.timestamp <= pool.lastUpdateTime) return;

        uint256 supply = pool.totalStaked;
        if (supply == 0) {
            pool.lastUpdateTime = block.timestamp;
            return;
        }

        uint256 timeDelta = block.timestamp - pool.lastUpdateTime;
        pool.rewardPerTokenStored += (timeDelta * pool.rewardRate * 1e18) / supply;
        pool.lastUpdateTime = block.timestamp;
    }

    function _currentRewardPerToken(uint256 poolId) internal view returns (uint256) {
        Pool storage pool = pools[poolId];
        if (pool.totalStaked == 0) return pool.rewardPerTokenStored;
        uint256 timeDelta = block.timestamp > pool.lastUpdateTime
            ? block.timestamp - pool.lastUpdateTime
            : 0;
        return pool.rewardPerTokenStored + (timeDelta * pool.rewardRate * 1e18) / pool.totalStaked;
    }

    function _earned(uint256 poolId, address user) internal view returns (uint256) {
        UserInfo storage u = userInfo[poolId][user];
        return (u.amountStaked * _currentRewardPerToken(poolId) / 1e18) - u.rewardDebt;
    }

    // ─── User: stake ──────────────────────────────────────────────────────────

    /**
     * @notice Deposit tokens or ETH into a pool.
     *
     * @dev For ETH pools pass amount = 0 and attach msg.value.
     *      For ERC-20 / LP pools msg.value must be 0 and the caller must
     *      approve this contract to spend `amount` tokens beforehand.
     *
     * @param poolId  Pool identifier (1-based, as returned by poolCount).
     * @param amount  Token amount for ERC-20 / LP pools (ignored for ETH pools).
     */
    function stake(uint256 poolId, uint256 amount) external payable nonReentrant {
        Pool storage pool = pools[poolId];
        require(address(pool.rewardToken) != address(0), "StakingPool: pool not found");

        _updatePool(poolId);
        UserInfo storage user = userInfo[poolId][msg.sender];

        // Determine deposited amount before any state changes
        uint256 deposited;
        if (address(pool.stakingToken) == address(0)) {
            // ETH pool: amount parameter is ignored; use msg.value
            require(msg.value > 0, "StakingPool: send ETH to stake");
            deposited = msg.value;
        } else {
            // ERC-20 / LP token pool
            require(msg.value == 0, "StakingPool: do not send ETH for token pool");
            require(amount > 0,     "StakingPool: amount must be > 0");
            deposited = amount;
        }

        // Snapshot pending reward for existing stakers (before state update)
        uint256 pending = user.amountStaked > 0
            ? (user.amountStaked * pool.rewardPerTokenStored / 1e18) - user.rewardDebt
            : 0;

        // ── Effects (state changes first) ──────────────────────────────────
        user.amountStaked += deposited;
        pool.totalStaked  += deposited;
        user.rewardDebt    = user.amountStaked * pool.rewardPerTokenStored / 1e18;

        // ── Interactions (external calls last) ────────────────────────────
        if (pending > 0) {
            pool.rewardToken.safeTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, poolId, pending);
        }
        if (address(pool.stakingToken) != address(0)) {
            pool.stakingToken.safeTransferFrom(msg.sender, address(this), deposited);
        }

        emit Staked(msg.sender, poolId, deposited);
    }

    // ─── User: unstake ────────────────────────────────────────────────────────

    /**
     * @notice Withdraw a given amount from a pool.
     *         Any pending rewards are automatically claimed at the same time.
     */
    function unstake(uint256 poolId, uint256 amount) external nonReentrant {
        Pool storage pool = pools[poolId];
        UserInfo storage user = userInfo[poolId][msg.sender];

        require(amount > 0,                  "StakingPool: amount must be > 0");
        require(user.amountStaked >= amount, "StakingPool: insufficient staked");

        _updatePool(poolId);

        uint256 pending = (user.amountStaked * pool.rewardPerTokenStored / 1e18) - user.rewardDebt;

        // ── Effects ──────────────────────────────────────────────────────────
        user.amountStaked -= amount;
        user.rewardDebt    = user.amountStaked * pool.rewardPerTokenStored / 1e18;
        pool.totalStaked   -= amount;

        // ── Interactions ─────────────────────────────────────────────────────
        if (pending > 0) {
            pool.rewardToken.safeTransfer(msg.sender, pending);
            emit RewardClaimed(msg.sender, poolId, pending);
        }

        if (address(pool.stakingToken) == address(0)) {
            (bool ok, ) = payable(msg.sender).call{value: amount}("");
            require(ok, "StakingPool: ETH transfer failed");
        } else {
            pool.stakingToken.safeTransfer(msg.sender, amount);
        }

        emit Unstaked(msg.sender, poolId, amount);
    }

    // ─── User: claim rewards only ─────────────────────────────────────────────

    /**
     * @notice Claim accrued rewards without withdrawing the staked principal.
     */
    function claimReward(uint256 poolId) external nonReentrant {
        Pool storage pool = pools[poolId];
        UserInfo storage user = userInfo[poolId][msg.sender];

        _updatePool(poolId);

        uint256 pending = (user.amountStaked * pool.rewardPerTokenStored / 1e18) - user.rewardDebt;
        require(pending > 0, "StakingPool: nothing to claim");

        // ── Effects then Interactions ─────────────────────────────────────
        user.rewardDebt = user.amountStaked * pool.rewardPerTokenStored / 1e18;
        pool.rewardToken.safeTransfer(msg.sender, pending);
        emit RewardClaimed(msg.sender, poolId, pending);
    }

    // ─── View helpers ─────────────────────────────────────────────────────────

    /**
     * @notice Returns the unclaimed reward balance for a user in a given pool.
     */
    function pendingReward(uint256 poolId, address userAddr) external view returns (uint256) {
        return _earned(poolId, userAddr);
    }

    /**
     * @notice Returns (amountStaked, rewardDebt) for a user.
     */
    function getUserInfo(uint256 poolId, address userAddr)
        external view
        returns (uint256 amountStaked, uint256 rewardDebt)
    {
        UserInfo storage u = userInfo[poolId][userAddr];
        return (u.amountStaked, u.rewardDebt);
    }

    /**
     * @notice Returns the name of a pool.
     */
    function getPoolName(uint256 poolId) external view returns (string memory) {
        return pools[poolId].name;
    }

    // ─── Safety ───────────────────────────────────────────────────────────────

    /// @dev Accept ETH sent directly (needed to receive ETH for ETH pools).
    receive() external payable {}
}
